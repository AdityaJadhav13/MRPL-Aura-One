# Dossier V0 — results

**Status: NOT COLLECTED. M0C is OPEN.**

No printed target has been photographed by any smartphone. This document
exists so that the session which does that has somewhere to put its answers,
and so the distinction between what is known and what is assumed is visible
rather than implied.

Every section is tagged:

| Tag | Meaning |
|---|---|
| **OBSERVED** | Measured from real photographs. |
| **CALCULATED** | Computed from synthetic renders or from algebra. True of the code; says nothing about a camera. |
| **PROVISIONAL INTERPRETATION** | A reading of CALCULATED evidence that real data could overturn. |
| **UNKNOWN** | Not yet answered. |

> **There is currently no OBSERVED content in this document.**

---

## 0. M0C status — 2026-09-26

**M0C BLOCKED — PHYSICAL EVIDENCE REQUIRED.**

A preflight was run to determine whether physical capture could begin. It
cannot, for two independent reasons.

### Blocker 1 — no physical Android device (hard)

| Check | Result |
|---|---|
| `adb devices` | empty |
| `flutter devices` | macOS and Chrome only |
| USB enumeration | no phone attached |

Directive §1 and §69 are explicit that simulator success, mock cameras and
synthetic fixtures cannot satisfy M0C. At least one real Android handset must
complete launch → capture → guidance → still processing → acquisition decision
against a real printed target. No such device is available, so no part of the
physical programme can start.

### Blocker 2 — no colour printer (material, independent)

Two printers are configured, and both report `*ColorDevice: False`:

| Printer | Driver | Colour |
|---|---|---|
| Canon LBP2900 | Canon LBP3000 CAPT | **No** — monochrome laser |
| HP LaserJet P1007 | HP LaserJet PCL 4/5 | **No** — monochrome laser |

Badge V1 carries ten reference patches, of which **six are chromatic**
(`REF-RED`, `REF-GREEN`, `REF-BLUE`, `REF-CYAN`, `REF-MAGENTA`, `REF-YELLOW`)
and four are neutral (`REF-BLACK`, `REF-DARK`, `REF-MID`, `REF-LIGHT`).

A monochrome laser renders all six chromatic patches as grey levels. The
consequence is not cosmetic: M0A already established that a neutral-only
reference set is **rank deficient** for fitting a 3×3 colour correction matrix.
Printing Badge V1 in monochrome reproduces precisely that rank deficiency in
physical form, which would block:

- §34 — comparison of correction methods (the CCM and affine arms have no
  chromatic constraints to fit)
- §36 — multi-reference correction and its conditioning
- §37 — withheld-reference validation, the mandatory check
- §38 — the reference-design experiment
- §53 — cross-light and cross-device colour metrics

The geometry half of M0C — detection, identification, rectification, secondary
marker validation, occlusion, distance, rotation, perspective, deformation,
blur, false acceptance — would survive a monochrome print, because those depend
on the black fiducials and the substrate rather than on chromatic patches. So a
monochrome print permits a *partial* M0C once a phone exists. It cannot produce
a complete one.

**This is recorded as a finding, not a workaround.** Nothing here should be read
as permission to proceed on grey patches and call the colour half done.

### What was prepared this phase

Preparation only. None of it is evidence.

| Artefact | Purpose |
|---|---|
| `measurement-engine/tool/generate_print_sheet.dart` | A4 sheet: 4 specimens (§50), a 100 mm scale bar (§8), and a printed record block for printer, paper, mode, date and measured dimensions (§7). Fails loudly rather than silently dropping a record field off the page. |
| `geometry/badge-v1-sheet.svg` | The generated sheet, rendered and visually verified. |
| `research/m0c-threshold-inventory.md` | Every capture and quality threshold, its value, its origin, and the fact that **all 21 are `SYNTHETIC ONLY`**. |
| `research/m0c-protocol.md` | The capture runbook: print, measure, capture matrix, dataset layout, session-wise splitting, reporting definitions, colour-claim limits. |

### Verified as already in place

| Item | State |
|---|---|
| Canonical geometry | `badge-v1-research`, 60.0 × 40.0 mm, 4 primary + 6 secondary fiducials, 14 ROIs. Exported to the app with a SHA-256 manifest verified at load. |
| Printable target generator | Runs clean; emits a cut line and a 20 mm scale bar; carries the design-space colour warning in the SVG itself. |
| Dev capture route | `/profile/capture`, gated on `EnvironmentConfig.simulationAvailable`, absent from production builds. |
| `CaptureRecord` / `CaptureMetadata` | Already implements §12's no-fabrication rule via a three-state `MetadataAvailability` (`known` / `unavailable` / `unsupported`) rather than a nullable number. |

### Known gap, deliberately not closed — CLOSED in APP-INTEGRATION-01

> `ResearchSpecimen` (specimen, badge, batch, formulation, series level) was
> added once physical specimens were imminent, with serialisation tests. The
> reasoning below is kept as the record of why it waited.

`specimen_id` (§50) has no field in `CaptureRecord`. It is a trivial additive
change, and adding it now would be a speculative modification to a frozen engine
that no test could exercise, since no capture can occur. It is recorded here to
be added in the first session that has hardware — the one place where it can
actually be verified.

### One defect found and fixed in passing

Not an M0C finding — it surfaced because this phase ran the suite on a new
calendar day.

**Eight Home goldens failed overnight on a one-digit diff.** `TodaysShiftCard`
called `DateTime.now()` directly, so every golden containing Home baked in the
day it was generated and went red at the next midnight. The rendered pixels were
correct; the test was not hermetic.

The tempting fix — regenerate the goldens — would have been wrong twice: it
recurs tomorrow, and a suite that reddens on a schedule teaches people to run
`--update-goldens` without reading the diff, which is precisely the value
ADR-0010 says goldens exist to provide.

Fixed by adding `clockProvider` and injecting it into Home. **The goldens then
passed without being regenerated**, which is the proof that nothing visual
changed. `test/golden/hermetic_goldens_test.dart` now fails any *new* wall-clock
read, and records the 16 existing ones as explicit debt rather than refactoring
twenty files across a frozen UI during an M0C phase.

### Scientific state unchanged

`measurement-engine` was **not modified**. No engine change was made, because
§66 permits one only on physical evidence and none exists. M0C, S1, S2 and S3
all remain **OPEN**. No H₂S was involved at any point; M0C requires none.

---

## 1. Sample counts

**UNKNOWN.**

| | Planned | Collected |
|---|---|---|
| Physical printed targets | ≥ 2 (matte, semi-gloss) + 1 degraded print | 0 |
| Phones | ≥ 3 Android spanning tiers, + iPhone if available | **0** |
| Illumination classes | 6 | 0 |
| Geometry conditions per cell | ≥ 4 | 0 |
| Deliberate failure captures | ≥ 9 classes | 0 |
| **Total valid acquisitions** | — | **0** |
| **Total deliberate failures** | — | **0** |

Valid acquisitions and deliberate failures are counted separately and must
never be pooled: the failures exist to test refusal, and averaging them into a
detection rate would understate it while saying nothing about refusal.
`CaptureConditions.deliberateFailure` is what keeps the populations apart.

## 2. What was built instead

M0C's software half is complete and verified; its evidence half is not.

| | |
|---|---|
| Geometry single source of truth | Canonical in `measurement-engine/geometry/`, exported to the app, SHA-256 verified at load, CI fails on drift |
| Dev-only capture route | Wired at `/profile/capture`, behind the same guard that compiles simulation out of production |
| Capture archive | One directory per capture; original bytes never re-encoded; record written last so an interrupted capture is identifiable |
| Adversarial wrong-pose set | 17 permanent cases, asserting *refuse or be right* |
| Reference design experiment | Run on synthetic renders — §6 |
| Fiducial benchmark | Run on synthetic renders — `research/fiducial-benchmark.md` |

## 3. Devices

**UNKNOWN.** No `CameraCapabilities` has been read from any physical phone.

| Device | focus lock | exposure lock | WB lock | exp. comp. | ISO | exp. time | torch | lens |
|---|---|---|---|---|---|---|---|---|
| _(none)_ | | | | | | | | |

**CALCULATED**, from the plugin's API surface rather than from a device: the
`camera` plugin exposes **no white-balance lock on either platform**, so
`whiteBalanceLockSupported` is reported `false` and `whiteBalanceLocked` is
recorded `unsupported` rather than `false`. Whether that matters is Q10 and is
unanswered.

## 4. Fiducial benchmark

**CALCULATED** — synthetic fixtures only. Full table in
`research/fiducial-benchmark.md` §3. Summary: 100% detection across rotation,
perspective, scale 8–20 px/mm, defocus, uneven illumination, glare, background
lightness and illuminant colour, with worst centroid error ≤ 0.35 px except
print degradation (6.30 px at heavy fade). Occlusion refuses.

**UNKNOWN:** ArUco and AprilTag have **not** been benchmarked. OpenCV is
unavailable in this environment. The custom detector has therefore not beaten
anything; it is the incumbent on probation.

**UNKNOWN:** everything about real photographs.

### False acceptance

**CALCULATED.** This is the metric that matters, per M0B-5.

| Adversarial family | Cases | Confident wrong poses |
|---|---|---|
| Missing primary marker | 4 | 0 |
| Half-covered marker | 2 | 0 |
| Decoy square outside the badge | 2 | 0 |
| Decoy replacing a removed corner | 1 | 0 |
| Dark background squares | 1 | 0 |
| Printed text on the badge | 1 | 0 |
| Badge cropped by the frame | 2 | 0 |
| Glare over a corner | 1 | 0 |
| Rotated with decoys | 1 | 0 |
| Occluder across a corner | 1 | 0 |
| **Total** | **16** | **0** |

The suite asserts a one-sided property — *refuse, or be right* — and never
requires detection to succeed. A refusal costs one retake; a confident wrong
pose puts a number on a health record measured from the wrong part of the
badge.

**PROVISIONAL INTERPRETATION:** the two guards added for this (geometry
cross-check against withheld markers, and marker-area consistency projected
through the pose) appear sufficient on synthetic adversaries. Real photographs
will contain adversaries nobody thought to render.

## 5. New findings this milestone

### M0C-1 — a half-covered marker reports a displaced centre **[fixed]**

**CALCULATED.** The adversarial suite found that covering half of `FID-BR`
still produced a blob, and the detector accepted it with the centroid **14 px
from truth** — about 1 mm of badge at the test scale. The geometry cross-check
did not catch it: the error is small enough that the secondary markers still
land inside their matching tolerance.

1 mm matters. ROI erosion margins on badge v1 are 0.55–1.0 mm, so a 1 mm pose
error can pull a neighbouring reference patch into a sampling window.

**Fix:** each marker's expected pixel area is projected through the pose and
compared against the detected blob. Half coverage reads ~50% and is refused
with `DetectionRejection.markerSizeInconsistent`.

The area is computed by **projecting the marker's own square through the
homography**, not from a single global pixels-per-mm — under perspective a
marker on the far side of the badge is legitimately smaller, and a global scale
rejected it for being exactly what it should be.

### M0C-2 — print degradation is accepted at 6.30 px error **[open]**

**CALCULATED.** At 80% fade toward the substrate the detector still reports
success with a worst centroid error of 6.30 px. Neither the area check nor the
geometry cross-check catches it, because the whole badge fades together and the
error is consistent across markers.

**Not fixed.** The right threshold depends on what a genuinely badly printed
badge looks like, which is a V0 question (the deliberately degraded print).
Recorded so it is not mistaken for a clean result.

## 6. Reference correction and reference design

**CALCULATED** — synthetic per-channel illuminant gains, from
`tool/reference_design_experiment.dart`. Holdout patches `REF-MAGENTA` and
`REF-DARK` are withheld from every fit.

| Reference set | Patches | Form | Rank | Condition | Holdout cross-illuminant ΔE₀₀ |
|---|---|---|---|---|---|
| RAW (no correction) | 0 | — | — | — | **10.41** |
| BLACK + WHITE (QRsens two-point) | 2 | QRsens Eq. 2 | — | — | 0.67 |
| NEUTRAL ONLY | 3 | — | 3 | 3.1e7 | **REFUSED** (ill-conditioned) |
| NEUTRAL + 2 chromatic | 4 | affine 3×4 | 4 | 1.7e2 | 0.51 |
| NEUTRAL + 3 chromatic | 5 | affine 3×4 | 4 | 5.5e1 | **0.34** |
| FULL V1 (7 fitted) | 7 | affine 3×4 | 4 | 6.3e1 | 0.41 |

The metric is the largest pairwise ΔE₀₀ for a **held-out** patch across three
illuminants — "does the same patch read the same under different light". It is
comparable across all methods including raw and the two-point correction.
Absolute colorimetric accuracy is **not** reported, because the targets are
design-space values and not measured print (§7).

**OBSERVED:** nothing. All of the above is synthetic.

**PROVISIONAL INTERPRETATION**, and the caveat is larger than the result:

- Correction of some kind is worth roughly a **30× reduction** in
  cross-illuminant spread on this stimulus (10.41 → 0.34).
- An all-neutral strip is **refused**, confirming design rule R4
  experimentally rather than by argument.
- Five patches (2 neutral + 3 chromatic) is the knee. Seven is no better and
  here marginally worse.
- **The two-point correction scores 0.67, which is suspiciously good — and the
  reason is that the modelled distortion is a pure per-channel gain, which is
  exactly what a two-point correction removes.** Real illuminants have spectra.
  Metamerism is not modelled here at all.

**Therefore: do not cut reference patches on this evidence.** The experiment
that discriminates between two points and five is the one with real light in
it. What this run does establish is the *lower bound* on what is needed: fewer
than four patches, or four collinear ones, cannot support a correction at all.

## 7. Colour ground truth

**UNKNOWN.** No printed target has been measured with a spectrophotometer or
colorimeter.

Until one is, the values in `badgeV1Colours` are **design-space digital
values**, not measured printed colour, and the app records them as such
(`capture_host_screen.dart`). Conclusions available without an instrument:
repeatability, cross-device spread, cross-illuminant spread, correction
consistency. Conclusions **not** available: any claim of absolute colorimetric
accuracy.

## 8. Preview versus still

**UNKNOWN.** The machinery exists — `CaptureRecord` carries both the last
preview assessment and the still assessment, and the app already re-runs the
authoritative checks on the still — but no matched pair has been collected.

Specifically unanswered: how often a preview reporting `ready` yields a still
that is refused, and which metrics diverge enough that a preview value must
never gate the still.

## 9. Geometry findings on real photographs

**UNKNOWN.** No bend tolerance exists. `validateGeometry` measures and reports
and has no `passed` field, deliberately, because the quantity that separates
acceptable handling variation from a badge that should be rejected is physical
and has never been measured.

**CALCULATED:** on synthetic renders a 1.6 mm bow leaves < 1e-8 px residual on
the four fitting points and > 5 px on the withheld ones, so the redundant
control design does detect non-planarity in principle.

## 10. Contamination

**UNKNOWN.** No contamination experiment has been run.
`CONTAMINATION_SUSPECTED` still has no threshold, and none has been invented.
`RoiSample.maximumChannelIqr` is the intended basis.

## 11. Provisional threshold inventory

Every threshold in the pipeline, with its evidence. **None has empirical
support from photographs.**

| Threshold | Where | Current | Source | Valid dist. | Invalid dist. | Proposed | FA | FR |
|---|---|---|---|---|---|---|---|---|
| Held-out correction limit | `validateCorrection(maximumDeltaE00:)` | 2.0 ΔE₀₀ | chosen | UNKNOWN | UNKNOWN | UNKNOWN | — | — |
| Correction condition limit | `fitCorrection(maximumConditionNumber:)` | 1.0e6 | chosen; synthetic sets land at 5.5e1–1.7e2 valid, 3.1e7 degenerate | CALCULATED | CALCULATED | keep | 0 | 0 |
| Rank tolerance | `fitCorrection(rankTolerance:)` | 1e-10 | numerical | — | — | keep | — | — |
| Sharpness floor | `AcquisitionLimits.minimumLaplacianVariance` | 1e-4 | chosen; **scale-dependent** | UNKNOWN | UNKNOWN | UNKNOWN | — | — |
| High-clip limit | `AcquisitionLimits.maximumHighClipFraction` | 0.02 | chosen | UNKNOWN | UNKNOWN | UNKNOWN | — | — |
| Specular limit | `AcquisitionLimits.maximumSpecularFraction` | 0.01 | chosen | UNKNOWN | UNKNOWN | UNKNOWN | — | — |
| Exposure window | `AcquisitionLimits` luma mean | 0.18–0.92 | chosen | UNKNOWN | UNKNOWN | UNKNOWN | — | — |
| Scale window | `AcquisitionLimits` px/mm | 8–40 | benchmark clean 8–20 | CALCULATED | UNKNOWN | UNKNOWN | — | — |
| Tilt limit | `AcquisitionLimits.maximumTiltRatio` | 1.25 | chosen | UNKNOWN | UNKNOWN | UNKNOWN | — | — |
| Centre offset | `AcquisitionLimits.maximumCentreOffsetFraction` | 0.16 | chosen | UNKNOWN | UNKNOWN | UNKNOWN | — | — |
| Auto-capture run | `AutoCaptureGate.requiredFrames` | 5 | chosen | UNKNOWN | UNKNOWN | UNKNOWN | — | — |
| Auto-capture span | `AutoCaptureGate.requiredSpan` | 600 ms | chosen | UNKNOWN | UNKNOWN | UNKNOWN | — | — |
| Pose drift | `AutoCaptureGate.maximumPoseDriftPx` | 6 px | chosen | UNKNOWN | UNKNOWN | UNKNOWN | — | — |
| Blob fill ratio | `BlobFilter.minimumFillRatio` | 0.42 | **geometric** — must stay below the 0.5 rotated-square floor | CALCULATED | CALCULATED | keep | 0 | 0 |
| Blob aspect | `BlobFilter.maximumAspectRatio` | 2.2 | chosen | CALCULATED | CALCULATED | UNKNOWN | — | — |
| Blob minimum pixels | `BlobFilter.minimumPixels` | 40 | chosen | UNKNOWN | UNKNOWN | UNKNOWN | — | — |
| Marker area ratio | `detectPrimaryFiducials(minimum/maximumMarkerAreaRatio:)` | 0.62–1.9 | M0C-1; half coverage = 0.5 | CALCULATED | CALCULATED | UNKNOWN | 0 | 0 |
| Secondary agreement | `minimumSecondaryAgreement` | 0.6 | M0B-5 | CALCULATED | CALCULATED | UNKNOWN | 0 | 0 |
| Secondary tolerance | `secondaryToleranceMm` | 1.5 mm | chosen | UNKNOWN | UNKNOWN | UNKNOWN | — | — |
| Orientation margin | `minimumOrientationMargin` | 1.06 | design R2 gives 1.25 | CALCULATED | CALCULATED | keep | 0 | 0 |
| Threshold tolerance | `adaptiveThreshold(tolerance:)` | 0.12 | chosen | UNKNOWN | UNKNOWN | UNKNOWN | — | — |
| ROI sample guards | `SampleGuards` clip/specular | 0.99 / 0.01 / 0.95 / 0.06 | chosen | UNKNOWN | UNKNOWN | UNKNOWN | — | — |
| **Bend tolerance** | not implemented | **none** | — | UNKNOWN | UNKNOWN | UNKNOWN | — | — |
| **Contamination limit** | not implemented | **none** | — | UNKNOWN | UNKNOWN | UNKNOWN | — | — |

Two thresholds are **geometric or numerical rather than empirical** and do not
need photographs: the fill-ratio floor (0.5 is a property of squares) and the
rank tolerance.

Even after V0, thresholds stay PROVISIONAL until tested on an independent set.
Tuning to the first small dataset is how a pipeline learns that dataset rather
than the problem.

## 12. No combined quality score

**CALCULATED, and enforced by test.** `ImageQuality.toJson()` has no `score`
or `overall` key, and a test asserts their absence. Each axis is reported and
gated separately, so a capture fails for a reason a person can act on.

## 13. The twelve questions

| | Question | Status |
|---|---|---|
| Q1 | Reliably find the real printed badge? | **UNKNOWN** |
| Q2 | Avoid plausible wrong poses? | CALCULATED: 0/16 adversarial. Real: **UNKNOWN** |
| Q3 | Rectification work on real photographs? | **UNKNOWN** |
| Q4 | Cross-light raw colour variation? | CALCULATED 10.41 ΔE₀₀ synthetic. Real: **UNKNOWN** |
| Q5 | How much does correction reduce it? | CALCULATED ~30× on a gain-only stimulus. Real: **UNKNOWN** |
| Q6 | Does correction generalise to withheld colours? | CALCULATED yes, synthetic. Real: **UNKNOWN** |
| Q7 | Cross-device variation? | **UNKNOWN** — no device |
| Q8 | Are preview measurements representative? | **UNKNOWN** |
| Q9 | Which thresholds now have empirical support? | **None.** Two are geometric (§11) |
| Q10 | Which camera controls matter? | **UNKNOWN** |
| Q11 | Controlled-light hood needed? | **UNKNOWN** |
| Q12 | Which fiducial system for badge V1? | **UNDECIDED** — custom on probation; A and B unbenchmarked |
| Q13 | Which reference patches to retain? | **UNDECIDED** — synthetic says 5 is the knee, but the stimulus flatters two-point correction. Do not cut yet. |
| Q14 | What remains before chemical coupon imaging? | §14 |

## 14. What remains before chemical coupon imaging

1. **Run V0.** Everything above marked UNKNOWN.
2. **Benchmark ArUco and AprilTag** on those photographs, in Python.
3. **Decide the fiducial system and the reference set**, then freeze badge
   geometry V2.
4. **Set the bend and contamination thresholds** from the curved and
   contaminated targets.
5. **Gates S1, S2 and S3 remain OPEN and are untouched by any of this.** A
   reader can be excellent while the dosimeter is physically invalid.
   Optical validation is necessary, not sufficient, and passing V0 would say
   nothing about whether the badge integrates exposure, retains a response, or
   responds to H₂S rather than to mercaptans.
