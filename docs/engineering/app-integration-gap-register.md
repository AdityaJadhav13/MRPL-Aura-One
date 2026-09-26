# App integration gap register

**Phase:** APP-INTEGRATION-01. Source: `end-to-end-measurement-path.md`.

| Priority | Meaning |
|---|---|
| **P0** | Blocks tomorrow's physical test |
| **P1** | Blocks correct measurement behaviour |
| **P2** | Blocks operational workflow |
| **P3** | Polish / future production |

Status is filled in at the end of the phase. A gap marked **BLOCKED** can only
be closed by physical evidence, and is not a software failure.

---

## P0 — blocks tomorrow's physical test

| ID | Gap | Consequence tomorrow | Status |
|---|---|---|---|
| G-01 | `CaptureArchive` exists and is never called | Every image, feature and metadata record discarded when the screen closes | **FIXED** — `ResearchRecorder` archives observed *and* refused captures; original bytes, rectified view, full record. Proved end to end, including a restart read-back. |
| G-02 | `deviceModel` records the camera id (`"0"`); `deviceManufacturer` records `"android"` | Cross-device data untraceable by device | **FIXED** — read from the platform via `device_info_plus`; `unavailable` rather than a guess when it will not say. |
| G-03 | Preview guidance measures px/mm on a ¼-scale frame against still-scale limits | Guidance can never report *ready* | **FIXED** — px/mm limits scaled by the preview downscale. Regression test proved load-bearing: with the old behaviour it reports `moveCloser`, with the fix `ready`. |
| G-04 | No `specimen_id` on `CaptureRecord` | X0–X3 captures cannot be told apart | **FIXED** — `ResearchSpecimen` (specimen, badge, batch, formulation, series level), kept separate from badge identity; series level carries no dose. Record schema → `/2`. |
| G-08 | No Physical Capture Test workflow; no diagnostics view | Specimen entry, save, inspect and next-specimen all impossible on the phone | **FIXED** — Profile → Physical capture test → camera → diagnostics → save → next, dev-gated and absent from production (tested). Also fixed: live guidance never resumed after the first capture. |
| G-16 | Android APK never built in this state | Nothing to install | **FIXED** — release and debug dev-flavor APKs in `dist/`, checksummed. **Not run on a device**: the attached phone stayed `unauthorized`. |

## P1 — blocks correct measurement behaviour

| ID | Gap | Status |
|---|---|---|
| G-05 | Calibration is a direct call; no interface for a real model | **FIXED** — `Calibration` interface, `NoCalibration` the only implementation, `CalibrationPackage` schema, and `calibrationMismatch` which refuses a simulated calibration on a real capture, a wrong geometry or a wrong feature definition. |
| G-06 | Expiry ROI defined in geometry, never sampled | **FIXED** — sampled and stored; produces no feature and no expiry claim. |
| G-07 | Secondary-marker residuals never gate a result | **BLOCKED — needs M0C evidence.** Residuals are recorded and shown; no rejection limit exists, and inventing one before physical captures would be tuning on nothing. |
| G-11 | `Valid`'s calibration-id guard is an `assert`, stripped from release builds | **MITIGATED** — tests prove `NoCalibration` never yields `Valid` or `Censored` in any domain. The assert itself remains; hardening it touches a `const` constructor across the engine, and is recorded for the phase that introduces a real calibration. |
| G-12 | Worker Scan path is entirely simulated | **DEFERRED — deliberate.** The worker flow's badge is a `BadgeSpecimen` from the simulation catalogue, and `MeasurementRecord` carries its own `DataDomain` enum that defaults to `simulated`. Wiring a real camera into it would attach a real photograph to a simulated badge identity — creating a provenance error, not removing one. Real optics run through the Physical Capture Test; the worker path stays labelled SIMULATED until real badge identity (QR) exists. |
| G-13 | No integration test drives image bytes through the orchestration layer | **FIXED** — 16 tests: encoded JPEG → real decoder → controller → engine → calibration → recorder → archive, plus undecodable bytes, no target, cropped, simulated calibration, collapsed references. |

## P2 — blocks operational workflow

| ID | Gap | Status |
|---|---|---|
| G-09 | No way to get a capture off the phone | **FIXED** — share one capture or the session manifest (`share_plus`, no storage permission); `adb run-as` bulk pull with the debug build. Labelled *research capture export*, never a report. |
| G-10 | Reference patch design values duplicated | **FIXED** — single app-side definition, with a test that fails on a one-byte drift from the canonical values. |
| G-14 | Repeated DEMO labels make the product read as a mockup | **FIXED** — 30 per-row demo chips removed by one policy getter; 27 screen banners kept (one per screen, none duplicated); environment indicator added to Profile; `notConnected` chips and SIMULATED markers untouched. |
| G-15 | Engine monotonicity tool requires a dose axis | **FIXED** — ordinal X0–X3 comparison: direction, reversals, separation. Descriptive, no verdict, no dose; excludes refusals and staged failures. |

## P3 — polish / future

| ID | Gap | Status |
|---|---|---|
| G-17 | Stills are not EXIF-rotated | OPEN — measurement unaffected (homography is orientation-independent); diagnostics may show the original sideways. Verify on device. |
| G-18 | 16 files still read the wall clock directly (tracked by `hermetic_goldens_test.dart`) | OPEN — known debt |

## Found during the phase

| ID | Gap | Status |
|---|---|---|
| G-19 | Live guidance never resumed after a capture — every capture after the first was blind | **FIXED** — `CaptureController.resume()` |
| G-20 | Profile showed **"Pending: 2"** under *Sync* — a hard-coded count implying records queued for a backend that does not exist | **FIXED** — replaced by an honest environment block |
| G-21 | Profile showed **Algorithm `cv-0.1.0`**; the engine identifies as `m0a` | **FIXED** — versions read from the running code |
| G-22 | Profile showed **Environment `dev`** hard-coded, whatever the build | **FIXED** — reads the build's environment |
| G-23 | Research records stamped app version `0.1.0` against a `0.1.0+1` build | **FIXED** — single-sourced, bumped to `0.2.0+2`, tested against `pubspec.yaml` |
| G-24 | The navigation guard "absent from a production build" passed vacuously once a new entry pushed the item off-screen | **FIXED** — the test scrolls to the end first; research routes gained the same three guards |
| G-25 | `CaptureRecord` kept features but not the ROI samples or fitted correction they came from | **FIXED** — full observation, correction method, homography and measurement status on the record |
| G-26 | `MeasurementRecord` duplicates the engine's `DataDomain` enum and **defaults it to `simulated`** | OPEN — the default fails safe today, but it is a second definition and a default the engine forbids. Resolve with G-12. |
| G-27 | `INTERNET` permission declared in the main manifest; no code makes a network request | OPEN — pre-existing, declared ahead of the planned backend (ADR-0005). An install-time permission with no prompt; disclosed rather than removed. |
| G-28 | APK built from an uncommitted working tree (188 paths over `c1ae135`) | OPEN — **commit before the physical session**, so captures can be traced to source. Identified meanwhile by `dist/SHA256SUMS`. |
