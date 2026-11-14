# my-jai-curve

Jai keyframe and curve type declarations for `float`, `Vec2`, `Vec3` and `Vec4` curves.
Curve evaluation is not implemented yet.

## Dependencies

Direct module dependencies:

- [my-jai-math](https://github.com/gorevojd/my-jai-math): vector types and math operations.

Jai standard library: `Basic`, `Sort`.

## Import

```jai
#import "my-jai-curve";
```

Add the parent directories of this module and its dependencies to the compiler's
module search path. Install the dependencies' own dependencies as documented in
their READMEs.

In this project, both modules are located under `Src/Modules/my-jai-core`, so add
that directory to the search path. The curve module can also be used independently:
`my-jai-core` re-exports its API, but is not a dependency of `my-jai-curve`.
