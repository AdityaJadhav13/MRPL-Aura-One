# Release notes — DoseBand 0.3.0+3 (Product Build v1)

| | |
|---|---|
| Display name | DoseBand Dev |
| Package | `in.doseband.h2s.dev` |
| Version / versionCode | 0.3.0 (`0.3.0-dev`) / 3 |
| Flavour | dev, entry `lib/main_dev.dart` |
| Build source | `8aa5355` (clean tree; untracked research PDFs only) |
| APK | `dist/doseband-productbuild1-0.3.0+3-8aa5355-dev-release.apk` |
| SHA-256 | `b5e7d7b1b99690ffaf69e72d8995a765cabb5a1706318929943274878a0484ff` |
| Permissions | CAMERA (runtime), INTERNET, AndroidX receiver permission |
| minSdk / targetSdk | 24 / 36 |
| Toolchain | Flutter 3.47.5, Dart 3.13.4, Android SDK 36, JDK 21 |

## New

* One role-based application: worker, supervisor, HSE, management and
  administrator workspaces over one on-device operations store.
* Sign-in against presentation accounts (salted verifiers), role from the
  directory, workspace switching, session restore, route gate.
* DoseBand QR contract v1, scanner, pre-use check (READY / REPLACE /
  CANNOT VERIFY), atomic claim-and-start, final-scan identity check.
* Worker Home states A–E, contextual Scan, history with period filters,
  read-only company profile.
* Supervisor team view, monitoring pipeline, exceptions and close-out.
* HSE register, traceability, reviews, dispositions and CSV/JSON reports.
* De-identified management views; administration of people and inventory
  with printable QR labels.

## Unchanged, deliberately

* No quantitative H₂S result: no validated calibration (M0C, S1–S3 open).
* REF-BLACK behaviour and all optical thresholds untouched.
* `measurement-engine` unchanged.

## Not connected

Organisation identity, central server, sync, every enterprise integration,
PDF export.

## Not verified on hardware

This artifact has not been installed on a physical phone (none available).
