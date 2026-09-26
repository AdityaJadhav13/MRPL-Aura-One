# End-to-end measurement path — as found

**Phase:** APP-INTEGRATION-01 · **Audited:** 2026-09-26, before any change.

This records what the code *did* at the start of the phase, not what it was
intended to do. Directive §4: do not assume components are connected merely
because they exist separately. One of them was not (see step 12).

There are **two** capture paths, and they share almost nothing.

---

## Path A — the worker's "Scan DoseBand"

`/scan` → `/read` → `/processing` → `/result`

| Step | UI entry | Implementation | Real / Simulated | Output |
|---|---|---|---|---|
| 1 | Scan tab | `ScanScreen` | Real (router hub) | routes to assign or read |
| 2 | Guided scan | `GuidedScanScreen` | **SIMULATED** — scripted checks lock on a timer; no camera behind it | none |
| 3 | Processing | `ProcessingScreen` | **SIMULATED** — stage list played out on a timer | a `MeasurementRecord` from `simulation_catalog.dart` |
| 4 | Result | `ResultScreen` / `ResultView.of` | Real presentation of a **simulated** result | rendered readout |

**No step of Path A touches a camera, an image, or `package:measurement`'s
image pipeline.** Every screen carries the SIMULATED marker, so this is honest —
but it means pressing Scan DoseBand on a physical phone tomorrow photographs
nothing.

---

## Path B — the development capture route

`/dev/capture` (gated on `EnvironmentConfig.simulationAvailable`)

| # | Step | Implementation | State | Input → Output | Failure states |
|---|---|---|---|---|---|
| 1 | Geometry load | `GeometryAssets().load('badge-v1-research')` | **Real.** SHA-256 verified against the manifest; no fallback | asset → `BadgeGeometry` | `GeometryAssetException` → capture never starts |
| 2 | Camera open | `CameraPortImpl.open()` | **Real.** Back camera, `enableAudio: false`, capabilities probed | — → `CameraCapabilities` | `CameraUnavailable` |
| 3 | Measurement settings | `applyMeasurementSettings()` | **Real.** Focus/exposure lock attempted, refusals recorded | — → requested-vs-applied map | per-setting `refused:<code>` |
| 4 | Preview frames | `previewFrames()` → `_toRgb(downscale: 4)` | **Real.** YUV420 on Android | `CameraImage` → `RgbImage` (¼ scale) | unsupported format → frame dropped |
| 5 | Guidance | `assessFrame()` (engine) | **Real code, BROKEN in use** — see G-03 | frame → `GuidanceAssessment` | badge-not-found, move closer/farther, glare, blur… |
| 6 | Arming | `AutoCaptureGate` | Real, **disabled** (`autoCapture: false`) | assessments → armed? | — |
| 7 | Still | `captureStill()` → `takePicture()` | **Real.** Original bytes kept | → `CapturedStill` | `CameraUnavailable` |
| 8 | Decode | `decodeStill()` (engine, `package:image`) | **Real.** EXIF orientation *not* applied — preview and still both arrive in sensor orientation, so they agree | bytes → `RgbImage` | `FormatException` |
| 9 | Metadata | `CaptureMetadata` | **Real, WRONG** — see G-02 | → metadata | — |
| 10 | Still re-assessment | `assessFrame()` on the still | **Real.** Authoritative; the preview is not | still → assessment | `STILL_FAILED_ACQUISITION_CHECKS` |
| 11 | Fiducials | `detectPrimaryFiducials()` (engine) | **Real** | still → 4 primaries + all blobs | `FIDUCIALS_NOT_FOUND_IN_STILL` |
| 12 | Homography | `estimateHomography()` (engine) | **Real** | correspondences → H | `GEOMETRY_NOT_RECOVERED` |
| 13 | ROI sampling | `sampleRoi()` inside `observe()` | **Real** for sensor, blank, 6 fit + 4 holdout references. **Expiry ROI not sampled** — G-06 | image + H → `RoiSample`s | `REGION_UNREADABLE` |
| 14 | Reference correction | `fitCorrection()` → `validateCorrection()` | **Real**, fit on 6, validated on 4 withheld | samples → correction + holdout ΔE00 | conditioning refusal → no correction |
| 15 | Features | `observe()` | **Real** — linear RGB, Lab, chroma, usable fraction, IQR, corrected RGB/Lab, blank L\*, ΔE76, ΔE00, sensor−blank L\*, reference ΔE00 | → `FeatureVector` | — |
| 16 | Image quality | `measureImageQuality()` | **Real**, thresholds `SYNTHETIC ONLY` | → `ImageQuality` | — |
| 17 | Deformation | `validateGeometry()` | **Real, NOT GATING** — residuals computed, never turned into a refusal, because no rejection limit exists (G-07) | H + blobs → residuals | — |
| 18 | Calibration | `refuseForLackOfCalibration()` | **Real refusal**, called directly — no interface (G-05) | observation → `Refused(unsupportedCalibration)` | — |
| 19 | Display | `_OutcomeLine` | **One line of text** | outcome → text | — |
| 20 | **Persistence** | `CaptureArchive.write()` | **NEVER CALLED** (G-01) | — | — |

---

## What this meant for a physical test

Pointing Path B at a real badge would have: opened the real camera; shown
guidance that could never report *ready* (G-03); taken a real still; run the
real pipeline end to end; recorded the phone's model as `"0"` and its
manufacturer as `"android"` (G-02); shown one line of text; and **discarded the
image, the features and the metadata** when the screen closed (G-01).

The optics would have worked. The evidence would not have survived.

See `app-integration-gap-register.md` for classification and resolution.

---

## After APP-INTEGRATION-01

Path B, re-traced. Path A (the worker's Scan) is unchanged and still simulated
— see G-12 for why that is deliberate.

| # | Step | Implementation | State |
|---|---|---|---|
| 0 | Entry | Profile → Developer and research tools → **Physical capture test** (`/dev/physical-capture`) | Real, dev-gated, absent from production |
| 1 | Specimen | `ResearchSettings` → `ResearchSpecimen` | Specimen required; series level ordinal only |
| 2 | Geometry | `GeometryAssets().load('badge-v1-research')` | Real, checksum-verified, no fallback |
| 3 | Camera | `CameraPortImpl` | Real; device identity from the platform (G-02) |
| 4 | Guidance | `assessFrame()` with px/mm limits scaled for the ¼ preview | Real, reachable (G-03) |
| 5 | Still | `takePicture()` → `decodeStill()` | Real; original bytes kept |
| 6 | Acquisition | still re-assessed → fiducials → homography | Real; the still is authoritative |
| 7 | Observation | `observe()` — sensor, blank, **expiry**, 6 fit + 4 holdout references | Real (G-06) |
| 8 | Correction | fitted, validated on withheld patches, **recorded** | Real (G-25) |
| 9 | Deformation | `validateGeometry()` | Recorded, not gating (G-07, blocked on evidence) |
| 10 | Calibration | `Calibration.interpret()` → `NoCalibration` | Typed refusal: `unsupportedCalibration` / `NO_CALIBRATION_MODEL` (G-05) |
| 11 | Diagnostics | `CaptureDiagnosticsScreen` | Overlays through the engine's homography; computes nothing itself |
| 12 | Persistence | `ResearchRecorder` → `CaptureArchive` | **Real, wired** — original, rectified view, full record (G-01) |
| 13 | Next | `CaptureController.resume()` | Live guidance restored (G-19) |
| 14 | Export | share one capture / session manifest; `run-as` pull | Research capture export, never a report (G-09) |
