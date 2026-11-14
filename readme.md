# my-jai-curve

Jai keyframe curves for `float`, `Vec2`, `Vec3` and `Vec4`, with key editing,
constant, linear and cubic interpolation, and tangent sampling.

## Dependencies

Direct module dependencies:

- [my-jai-math](https://github.com/gorevojd/my-jai-math): vector types, math operations and `hermite3` interpolation weights.

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

## Key editing

- `add_keyframe(*curve, key)` inserts a key in time order and returns its index.
  A key at exactly the same time is replaced; time comparisons use no epsilon.
- `remove_keyframe(*curve, index)` removes an existing key and preserves the order
  of the remaining keys.
- `update_keyframe(*curve, index, key)` replaces a key and returns its new index
  after repositioning. If another key already occupies the new time, it is replaced
  too, reducing the total key count by one.
- Every edit recalculates `Auto` tangents and copies the right tangent to the left
  for `User` keys. `Break` keys retain their independent tangents. `Auto` uses the
  slope between adjacent neighbors, or the one-sided slope at an endpoint; a lone
  `Auto` key has zero tangents.
- Indices can change after edits. Key times must be finite and unique; use the
  editing functions to keep keys sorted and tangents normalized. Removal and update
  require a valid index.
- `clear(*curve)` retains key storage; `destroy(*curve)` releases it.
  `get_time_range(curve)` returns the first and last key times, or `(0, 0)` when empty.

## Sampling

`sample(curve, time)` returns the value at a finite time. The left key selects the
interpolation mode for the segment leading to the next key:

- `Constant`: hold the left value until the next key's exact time.
- `Linear`: interpolate the two values; stored tangents are ignored.
- `Cubic`: Hermite interpolation using the left key's right tangent and the right
  key's left tangent. Tangents are derivatives with respect to time and are scaled
  by the segment duration in the weights returned by `my-jai-math.hermite3`.

`sample` computes only the value. It shares the interpolation implementation with
`sample_keyframe`, but derivative calculations are excluded at compile time for
`sample`; there is no runtime flag check for whether to compute them.

`sample_keyframe(curve, time)` returns a key at the requested time. Between keys,
its value matches `sample`, both tangents equal the curve's derivative, its tangent
mode is `User`, and its interpolation mode comes from the left key. At an existing
key's exact time it returns that key unchanged, preserving authored tangents and modes.

Outside the range, sampling holds the nearest endpoint value. A sampled key there
uses zero tangents and `User` / `Constant` modes. An empty curve samples as zero;
its sampled key also has zero tangents and `User` / `Constant` modes. Sampling does
not modify the curve or allocate memory. Time lookup is O(log n); edits are O(n).

## Invalid input

The editing and sampling APIs check invalid inputs with an `if`, a diagnostic
`assert(false, ...)` and an early return. These branches remain active when Jai's
`Basic.ENABLE_ASSERT` is disabled. With assertions enabled, the configured assertion
handler can still stop the program; the fallback return is reached if it allows
execution to continue.

- A null curve, non-finite key time or invalid edit index rejects the edit without
  changing the curve. `add_keyframe` and `update_keyframe` return
  `INVALID_KEY_INDEX` (`0xFFFFFFFF`); `remove_keyframe` returns immediately.
  The invalid index is reserved and cannot be assigned to a key.
- A non-finite sample time returns zero value and tangents, time zero, and
  `User` / `Constant` modes.
- An unsupported interpolation mode on the sampled segment returns zero value and
  tangents with `User` / `Constant` modes, preserving the requested time.
