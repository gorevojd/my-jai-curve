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
    #assert (T == float ||
             T == Math.Vec2 ||
             T == Math.Vec3 ||
             T == Math.Vec4) "CurveBase supports only float, Vec2, Vec3 and Vec4.";
}

#scope_module
Math :: #import "MyBasic/MyMath";

