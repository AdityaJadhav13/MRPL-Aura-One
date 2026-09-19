# Computer vision and colour pipeline

Everything here lives in `packages/measurement`, is pure Dart, has no Flutter dependency, and
runs in an isolate. Every stage is a function from typed input to typed output, so every stage
has a fixture test.

The governing rule is directive §45: **AI cannot reconstruct information the physical sensor
never captured.** Deterministic methods are used wherever they suffice, which is everywhere in
the current design.

## 0. Frame quality (live, on the preview stream)

Runs on downscaled preview frames at a few Hz — enough to guide, cheap enough not to heat the
phone.

| Metric | Method | Drives |
|---|---|---|
| Sharpness | Variance of the Laplacian on the luma plane | `HOLD STEADY`, blur rejection |
| Exposure | Luma histogram mean and percentiles | `MORE LIGHT NEEDED` |
| Clipping | Fraction of pixels at 0 or 255 per channel | `REDUCE GLARE`; a clipped channel is unrecoverable |
| Specular glare | Connected bright regions with low saturation over the badge area | `REDUCE GLARE` |
| Scale | Fiducial separation vs. expected | `MOVE CLOSER` / `MOVE FARTHER` |
| Tilt | Homography condition number and corner-angle deviation | `KEEP BADGE FLAT` |
| Stability | Frame-to-frame fiducial centroid displacement | auto-capture arming |

Auto-capture arms only when every metric holds within threshold across several consecutive
frames. Manual capture is always available — but a manual capture runs the *same* rejection
checks afterwards, so overriding the guidance does not override the measurement standard.

## 1. Fiducial detection

The badge carries four high-contrast corner markers at positions defined by
`badge_geometries.roi_definition`. Because we control the badge design, this is a solved
geometry problem rather than an open detection problem.

Adaptive threshold (integral-image Bradley) → connected components → filter by area, aspect
and fill ratio → sub-pixel centroid by intensity-weighted moments → identify the four by
relative geometry, with one asymmetric marker fixing orientation.

Fewer than four confident fiducials → refuse. Do not guess a fourth corner; a wrong homography
produces a beautifully rectified image of the wrong region.

## 2. Homography and rectification

Normalised DLT from the four correspondences (Hartley normalisation, then SVD of the 8×9
design matrix). Rectification is an inverse warp with bilinear sampling into canonical badge
millimetre space at a fixed pixels-per-mm.

Validity checks on the homography itself: condition number within bounds, positive
determinant, no extreme anisotropic scaling, and reprojection residual on the fiducials below
threshold. A curved or bent badge shows up here as elevated residual, which matters because
the dossier warns explicitly that a curved surface is not automatically planar.

Insufficient source resolution for the target pixels-per-mm → refuse. Upsampling invents
detail, and invented detail is exactly the failure mode this whole architecture exists to
prevent.

## 3. Colour science

Raw camera RGB is not a measurement. The phone has already applied white balance, tone
mapping and gamma before the app sees a pixel. The reference patches exist to undo an unknown
transform, and the held-out patches exist to prove the undoing worked.

Sequence:

1. **Linearise.** Remove the sRGB transfer function. All fitting happens in linear space;
   fitting in gamma-encoded space is a common and silent error.
2. **Sample patches.** Read each reference patch at its geometry-defined location, using a
   trimmed mean over the patch interior with an erosion margin to avoid print edges.
3. **Fit the correction.** Least squares from measured patch values to the profile's stored
   *measured* print values — not the printer's nominal RGB. Start with a 3×4 affine model.
   Escalate to 3×10 polynomial only if residuals justify it, decided by evidence, not taste.
4. **Validate on held-out patches.** Apply the fitted correction to patches excluded from the
   fit, convert to CIELAB (D65), compute ΔE₀₀ against their stored values. Exceeding
   `reference_profiles.max_delta_e` → `REFERENCE_PATCH_FAILURE`.
5. **Convert.** Corrected linear RGB → XYZ → CIELAB for all subsequent feature work.

Two things this cannot fix, and the app must not pretend otherwise: a clipped channel carries
no information to recover, and metamerism means ink and reacted chemistry that match under one
illuminant may diverge under another. Both are handled by rejection, not correction. The
dossier's recommendation of a controlled-light dock is the physical answer if rejection rates
prove too high in the field.

## 4. ROI extraction and features

ROIs come from the versioned geometry record: active window(s) A1/A2, protected blank B,
expiry patch E. Each is eroded inward before sampling so that edge effects and contamination
creeping in from the border do not enter the statistic.

Per ROI: median and trimmed mean in CIELAB, interquartile spread, spatial gradient magnitude,
reacted-area fraction against a threshold in the appropriate channel, and — for front-type
responses — reaction-front position and length.

Cross-ROI checks:
- **Blank vs. active.** A blank that has moved with the active region indicates a shared
  non-H₂S influence (humidity, light, ageing) rather than exposure → `BLANK_FAILURE` or
  `SENSOR_BLANK_DISAGREEMENT`.
- **Within-ROI heterogeneity.** High spread or a localised spot suggests a droplet, fibre or
  smear → `CONTAMINATION_SUSPECTED`. A uniform response is a property of a real one; a blotchy
  one is not to be averaged into confidence.
- **A1 vs. A2 consistency.** Where both windows exist and both are in range, they must agree
  within a calibrated tolerance. Disagreement is reported, not averaged away.

## 5. Calibration and inference

Start with monotonic interpolation over a lookup table, per the dossier. That is not a
placeholder for something better — it is the honest model for a chemistry with a monotonic
dose response and a modest number of calibration points, and it cannot produce the
non-physical wiggles a flexible regressor can.

```
features + calibration_model.parameters
  → dose estimate
  → uncertainty from calibration_model.uncertainty_model
  → domain check against validated_range and environmental_domain
  → censoring: below LoQ, above saturation
```

Hard rules:
- Never extrapolate beyond `validated_range`. Outside it, censor.
- Never report an interval labelled with a coverage probability unless
  `uncertainty_model` carries the evidence for that coverage. The default presentation is an
  interval with a stated basis, not a "95% CI".
- Never apply a model whose `algorithm_version` does not match the running pipeline's feature
  definitions.
- Never apply a model outside its `permitted_domains`.

ML is admitted later only under ADR-0003's conditions, and only for ROI localisation and
contamination rejection — never as the dose estimator without evidence it beats monotonic
interpolation on genuinely held-out specimens from a new lot and unseen phones.

## 6. Test fixtures

Fixtures are checked into `packages/measurement/test/fixtures/` with their expected outputs,
and the suite runs headless on `dart test` with no device.

Synthetic, generated by `tools/`: canonical badge renders at known dose levels, applied
perspective transforms, simulated illuminants, additive glare, defocus blur, sensor noise,
missing and damaged patches, saturated sensor, bent-badge warp.

Real, captured once the physical badge exists: printed optical targets photographed under
several illuminants and on several phone models — the dossier's V0 experiment. These are
genuine validation of the optical pipeline and are **not** simulation; they are labelled
`lab` domain and are how the CV pipeline earns trust before any chemistry exists.

The distinction matters and is enforced in the fixture manifest: a synthetic fixture can test
that the code is correct; only a photographed fixture can test that the code works on a camera.
