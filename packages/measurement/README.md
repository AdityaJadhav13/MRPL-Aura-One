# measurement

The H₂S DoseBand scientific core. Pure Dart. **No Flutter dependency, ever.**

```
CapturedFrame → FrameQuality → FiducialSet → Homography → CanonicalBadge
  → PatchSamples → ColourCorrection → CorrectionResidual (held-out patches)
  → RoiFeatures → CalibrationModel → MeasurementResult
```

Every stage is a pure function over typed input. No I/O, no clock, no ambient
randomness. That is what makes the whole pipeline fixture-testable headlessly:

```
dart test
```

Two invariants this package exists to hold:

1. **A failure is never a number.** `MeasurementResult` is a sealed union in which
   only `Valid` and `ValidWithWarning` carry a dose. The other states have no
   field to put one in.
2. **Fail closed.** Missing calibration, unknown lot, absent geometry, unreadable
   blank — every one produces a refusal. There is no path where absent
   information yields a value.

See `docs/computer-vision/pipeline.md` for the full specification.
