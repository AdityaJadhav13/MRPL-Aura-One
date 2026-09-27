# Release notes — DoseBand 0.4.0+4 (Product Build v1, UI recovery)

| | |
|---|---|
| Display name | DoseBand Dev |
| Package | `in.doseband.h2s.dev` |
| Version / versionCode | 0.4.0 (`0.4.0-dev`) / 4 |
| Flavour | dev, entry `lib/main_dev.dart` |
| Build source | `c5429cf` (clean tree; untracked research PDFs only) |
| APK | `dist/doseband-productbuild1-ui-recovery-0.4.0+4-c5429cf-dev-release.apk` (66.7 MB) |
| SHA-256 | `7478e2340fc68db710478004de1b0b40e02cce1d8e40724ee24457caa229c18b` |
| Permissions | CAMERA (runtime), INTERNET, AndroidX receiver permission (unchanged from 0.3.0) |
| minSdk / targetSdk | 24 / 36 |
| Toolchain | Flutter 3.47.5, Dart 3.13.4, Android SDK 36, JDK 21 |

## Recovered

The approved screens are back, recovered from git history and bound to
the current data. See `docs/design/ui-recovery-0.4.0.md`.

* **Splash:**
  * refinery at dusk;
  * the MRPL mark and organisation;
  * Safe People / Sustainable Operations;
  * the DoseBand lockup with the orange progress bar.
* **Sign in:**
  * the MRPL header;
  * a refinery strip with the DoseBand lockup;
  * the footer wave;
  * presentation accounts as role cards.
* **Worker Home:**
  * the refinery header;
  * the identity card;
  * Today's shift and Work context;
  * the strong monitoring card;
  * one state-driven action.

## Preserved

* The five-item floating navigation.
* History with the 7 days / 30 days / Custom filters.
* Contextual Scan, Safety and Profile.

Their goldens are byte-identical before and after the recovery.

## Fixed

* Scanner title was near-black on the camera's black.
* The splash could stay up forever if the stored session was unreadable.
* A tap during the session read was dropped.
* The Home identity card's screen-reader label now includes ID, company and storage.

## Unchanged, deliberately

* No quantitative H₂S result: there is no validated calibration (M0C, S1–S3 open).
* REF-BLACK behaviour and all optical thresholds are untouched.
* `packages/measurement` is unchanged (312 tests; parity 394/394; geometry drift 75).
* No gradients anywhere (ratchet 0).

## Not connected

* Organisation identity.
* A central server and sync.
* Every enterprise integration.
* PDF export.

## Not verified on hardware

This build has not been installed on a physical phone; none was available.
