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
    #assert (T == float || T == Math.Vec2 || T == Math.Vec3 || T == Math.Vec4) "CurveBase supports only float, Vec2, Vec3 and Vec4.";

    keys: [..] Keyframe(T);
}

Float_Curve :: CurveBase(float);
Vec2_Curve :: CurveBase(Math.Vec2);
Vec3_Curve :: CurveBase(Math.Vec3);
Vec4_Curve :: CurveBase(Math.Vec4);

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

add_keyframe :: (curve: *CurveBase($T), keyframe: Keyframe(T)) -> u32 {

}

remove_keyframe :: (curve: *CurveBase($T), key_index: u32) {

}

sample :: (curve: CurveBase($T), time: float) -> T {

}

sample_keyframe :: (curve: CurveBase($T), time: float) -> Keyframe(T) {

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
normalize :: (curve: *CurveBase($T), sort: bool = false) {
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
                tangent = (next.value - previous.value) / (next.time - previous.time) ;
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

