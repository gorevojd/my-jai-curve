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

    keys: [..] Keyframes;
}

get_time_range :: (curve: CurveBase($T)) -> float, float {

}

add_keyframe :: (curve: *CurveBase($T), keyframe: Keyframe(T)) -> u32 {

}

remove_keyframe :: (curve: *CurveBase($T), key_index: u32) {

}

sample :: (curve: CurveBase($T), time: float) -> T {

}

sample_keyframe :: (curve: CurveBase($T), time: float) -> Keyframe(T) {

}

clear :: (curve: *CurveBase($T)) {

}

destroy :: (curve: *CurveBase($T)) {

}

#scope_module
normalize :: (curve: *Curve) {

}

#scope_module
Math :: #import "MyBasic/MyMath";

