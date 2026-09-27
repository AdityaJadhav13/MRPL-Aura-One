# measurement-engine

Dart package name: `measurement`.

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

## Where things are

| Folder | Responsibility |
|---|---|
| `lib/src/imaging/` | Image decoding, pixel buffers, perspective rectification |
| `lib/src/geometry/` | Fiducial detection, homography, badge geometry and its validation |
| `lib/src/colour/` | sRGB ⇄ CIELAB, ΔE, reference-patch colour correction |
| `lib/src/linalg/` | Matrix algebra used by homography and colour fitting |
| `lib/src/calibration/` | Calibration model interface (no production model exists yet) |
| `lib/src/features/` | Region-of-interest sampling and robust statistics |
| `lib/src/quality/` | Image and acquisition quality gates |
| `lib/src/validity/` | `MeasurementResult`, the typed result and refusal states |
| `lib/src/capture/` | Capture metadata, guidance and stability |
| `lib/src/contract/` | The research pipeline contract and feature vectors |
| `geometry/` | Canonical badge geometry — the app's copy is generated from it |
| `golden-vectors/` | Stdlib-only Python reference and cross-language vectors |
| `badge-print/` | Printable badge target |
| `tool/` | Generators: geometry export, golden vectors, print sheets |
