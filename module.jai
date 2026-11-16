TangentMode :: enum {
    Auto;
    User;
    Break;
}

InterpolationMode :: enum {
    Constant;
    Linear;
    Cubic;
}

Keyframe :: struct (T: Type) {
    time: float;

    value: T;
    l_tangent: T;
    r_tangent: T;

    tangent_mode: TangentMode;
    interpolation_mode: InterpolationMode;
}

CurveBase :: struct (T: Type) {
    #assert array_find(AllowedCurveValueTypes, T) "CurveBase value type must be in AllowedCurveValueTypes.";

    keys: [..] Keyframe(T);
}

Float_Curve :: CurveBase(float);
Vec2_Curve :: CurveBase(Math.Vec2);
Vec3_Curve :: CurveBase(Math.Vec3);
Vec4_Curve :: CurveBase(Math.Vec4);

AllowedCurveValueTypes :: Type.[float, Math.Vec2, Math.Vec3, Math.Vec4];

INVALID_KEY_INDEX :: Math.U32_MAX;

/**
 * @brief Returns the first and last key times, or two zeros for an empty curve.
 * @param[in] curve Curve to inspect.
 * @return Start and end times.
 * @pre Keys are sorted by increasing time.
 */
get_time_range :: (curve: CurveBase($T)) -> float, float {
    if curve.keys.count == 0 {
        return 0.0, 0.0;
    }

    return curve.keys[0].time, curve.keys[curve.keys.count - 1].time;
}

/**
 * @brief Inserts a key in time order, or replaces the key at exactly the same time, and normalizes tangents.
 * @param[in,out] curve Curve to edit; must not be null.
 * @param[in] keyframe Key with a finite time.
 * @return Final index of the inserted or replaced key, or INVALID_KEY_INDEX on rejected input.
 * @pre Existing keys have unique times in increasing order.
 * @note Editing can change indices of other keys. Time equality is exact, without an epsilon.
 * @note Rejected inputs leave the curve unchanged.
 */
add_keyframe :: (curve: *CurveBase($T), keyframe: Keyframe(T)) -> u32 {
    if curve == null {
        assert(false, "Cannot add a key to a null curve.");
        return INVALID_KEY_INDEX;
    }

    if !Math.is_finite(keyframe.time) {
        assert(false, "Key time must be finite.");
        return INVALID_KEY_INDEX;
    }

    index := key_lower_bound(curve.*, keyframe.time);
    if (index < curve.keys.count &&
        curve.keys[index].time == keyframe.time) {
        curve.keys[index] = keyframe;
    }
    else {
        if curve.keys.count >= INVALID_KEY_INDEX {
            assert(false, "Curve has reached the key limit; INVALID_KEY_INDEX is reserved for errors.");
            return INVALID_KEY_INDEX;
        }

        array_insert_at(*curve.keys, keyframe, index);
    }

    normalize(curve);
    return cast(u32)index;
}

/**
 * @brief Removes a key without changing the order of the remaining keys, then normalizes tangents.
 * @param[in,out] curve Curve to edit; must not be null.
 * @param[in] key_index Index of an existing key. Later indices shift down by one.
 * @pre Existing keys have unique times in increasing order.
 * @note A null curve or invalid index asserts and returns without changing the curve.
 */
remove_keyframe :: (curve: *CurveBase($T), key_index: u32) {
    if curve == null {
        assert(false, "Cannot remove a key from a null curve.");
        return;
    }

    if key_index >= curve.keys.count {
        assert(false, "Key index is outside the curve.");
        return;
    }

    array_ordered_remove_by_index(*curve.keys, key_index);
    normalize(curve);
}

/**
 * @brief Replaces a key, moves it to its new time position and normalizes tangents.
 * @param[in,out] curve Curve to edit; must not be null.
 * @param[in] key_index Index of the key to replace.
 * @param[in] key Replacement key with a finite time.
 * @return Final index of the replacement key, or INVALID_KEY_INDEX on rejected input.
 * @pre Existing keys have unique times in increasing order.
 * @note If another key occupies the new time, it is replaced too and the key count decreases by one.
 * @note Rejected inputs leave the curve unchanged.
 */
update_keyframe :: (curve: *CurveBase($T), key_index: u32, key: Keyframe(T)) -> u32 {
    if curve == null {
        assert(false, "Cannot update a key in a null curve.");
        return INVALID_KEY_INDEX;
    }

    if key_index >= curve.keys.count {
        assert(false, "Key index is outside the curve.");
        return INVALID_KEY_INDEX;
    }

    if !Math.is_finite(key.time) {
        assert(false, "Key time must be finite.");
        return INVALID_KEY_INDEX;
    }

    array_ordered_remove_by_index(*curve.keys, key_index);
    return add_keyframe(curve, key);
}

/**
 * @brief Evaluates the curve, holding endpoint values outside its time range.
 * @param[in] curve Curve with normalized tangents and unique, increasing key times.
 * @param[in] time Finite sample time.
 * @return Interpolated value, or zero for an empty curve or rejected sample.
 * @details The left key selects Constant, Linear or Cubic (Hermite) interpolation for each segment.
 * @note Evaluates only the value; derivative calculations are excluded at compile time.
 */
sample :: (curve: CurveBase($T), time: float) -> T {
    key := sample_internal(curve, time, false);
    return key.value;
}

/**
 * @brief Evaluates a key at the requested time, including its time derivative.
 * @param[in] curve Curve with normalized tangents and unique, increasing key times.
 * @param[in] time Finite sample time.
 * @return A key at the requested time, or time zero if the requested time is non-finite.
 * @details
 * - At an existing key time, returns that key unchanged, including its modes and authored tangents.
 * - Between keys, uses the left key's interpolation mode and sets both tangents to the derivative; mode is User.
 * - Outside the time range, holds the nearest endpoint value with zero tangents and Constant interpolation.
 * - An empty curve returns a zero value and zero tangents with User and Constant modes.
 * - Invalid time or unsupported segment mode asserts and returns zero value/tangents with User and Constant modes.
 *   Invalid time returns time zero; an unsupported mode preserves the requested time.
 */
sample_keyframe :: (curve: CurveBase($T), time: float) -> Keyframe(T) {
    return sample_internal(curve, time, true);
}

/** @brief Removes all keys while retaining allocated storage and its allocator. */
clear :: (curve: *CurveBase($T)) {
    array_reset_keeping_memory(*curve.keys);
}

/** @brief Frees key storage, preserving its allocator. Leaves an empty, reusable curve; safe to repeat. */
destroy :: (curve: *CurveBase($T)) {
    array_reset(*curve.keys);
}

#scope_module
sample_internal :: inline (curve: CurveBase($T), time: float, $with_tangents: bool) -> Keyframe(T) {
    using Math;

    result: Keyframe(T);
    result.tangent_mode = .User;
    result.interpolation_mode = .Constant;
    if !Math.is_finite(time) {
        assert(false, "Sample time must be finite.");
        return result;
    }
    result.time = time;
    if curve.keys.count == 0 {
        return result;
    }

    index := key_lower_bound(curve, time);
    if index == curve.keys.count {
        result.value = curve.keys[index - 1].value;
        return result;
    }

    if curve.keys[index].time == time {
        return curve.keys[index];
    }

    if index == 0 {
        result.value = curve.keys[0].value;
        return result;
    }

    left := curve.keys[index - 1];
    right := curve.keys[index];
    result.interpolation_mode = left.interpolation_mode;
    if left.interpolation_mode == .Constant {
        result.value = left.value;
        return result;
    }

    duration := right.time - left.time;
    elapsed := time - left.time;
    if left.interpolation_mode == .Linear {
        t := elapsed / duration;
        result.value = Math.lerp(left.value, right.value, t);
        #if with_tangents {
            result.l_tangent = (right.value - left.value) / duration;
        }
    }
    else if left.interpolation_mode == .Cubic {
        base: [4]float;
        #if with_tangents {
            derivative_base: [4]float;
            base, derivative_base = Math.hermite3_with_derivative(elapsed, duration);
            result.l_tangent = left.value * derivative_base[0] +
                               right.value * derivative_base[1] +
                               left.r_tangent * derivative_base[2] +
                               right.l_tangent * derivative_base[3];
        }
        else {
            base = Math.hermite3(elapsed, duration);
        }
        result.value = left.value * base[0] +
                       right.value * base[1] +
                       left.r_tangent * base[2] +
                       right.l_tangent * base[3];
    }
    else {
        assert(false, "Unsupported curve interpolation mode.");
        result.interpolation_mode = .Constant;
        return result;
    }

    #if with_tangents {
        result.r_tangent = result.l_tangent;
    }
    return result;
}

key_lower_bound :: (curve: CurveBase($T), time: float) -> int {
    first := 0;
    last := curve.keys.count;
    while first < last {
        middle := first + (last - first) / 2;
        if curve.keys[middle].time < time {
            first = middle + 1;
        }
        else {
            last = middle;
        }
    }
    return first;
}

normalize :: (curve: *CurveBase($T), sort: bool = false) {
    using Math;
    if sort {
        key_time :: (key: Keyframe(T)) -> float {
            return key.time;
        }
        quick_sort(curve.keys, key_time);
    }

    for *key, index: curve.keys {
        if key.tangent_mode == .User {
            key.l_tangent = key.r_tangent;
            continue;
        }

        if key.tangent_mode == .Auto {
            tangent: T;
            if curve.keys.count > 1 {
                previous := curve.keys[max(index - 1, 0)];
                next := curve.keys[min(index + 1, curve.keys.count - 1)];
                tangent = (next.value - previous.value) / (next.time - previous.time);
            }

            key.l_tangent = tangent;
            key.r_tangent = tangent;

            continue;
        }
    }
}

#scope_module
#import "Basic";
#import "Sort";
Math :: #import "my-jai-math";

