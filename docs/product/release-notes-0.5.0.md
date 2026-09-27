# Release notes — DoseBand 0.5.0+5 (Worker experience)

| | |
|---|---|
| Display name | DoseBand Dev |
| Package | `in.doseband.h2s.dev` |
| Version / versionCode | 0.5.0 (`0.5.0-dev`) / 5 |
| Flavour | dev, entry `lib/main_dev.dart`, `--dart-define-from-file=config/presentation.local.json` |
| Build source | `acfcf2d` (clean tree) |
| APK | `dist/doseband-worker-0.5.0+5-acfcf2d-dev-release.apk` (66.7 MB) |
| SHA-256 | `0d61cc8da2915006917523aecc6f1c5d05377e590a103fa7db70a06ccd5be40e` |
| Permissions | CAMERA (runtime), INTERNET, AndroidX receiver permission — no location, audio or storage |
| minSdk / targetSdk | 24 / 36 |
| Toolchain | Flutter 3.47.5, Dart 3.13.4, Android SDK 36, JDK 21 |

## New

- **Sign In** rebuilt from the approved design, with:
  - Employee / Contractor;
  - Remember me (working);
  - an honest Forgot password;
  - the presentation account prefilled;
  - a New user entry point.
- **First-time setup:** Select Site, then Select Your Role, both rebuilt from the approved design.
- **Authentication and authorization are separate.**
  - Worker credentials with a role the account doesn't hold are refused: "This account is not authorized for the selected role. Select your assigned role and try again."
  - Invalid credentials get a different message.
- **Home** shows DoseBand status and the next action only.
- **Profile** takes the rich Home content: identity (photo-ready), Work Assignment and Work Context.
- **Settings:** account, privacy, About (version and build from package metadata), licences, Sign out.

## Removed

- From Sign In: the DEMO badge, the credentials card, Gate Pass and QR sign-in, and Skip.
- The one-tap presentation sign-in, which skipped the password check.
- Developer and research tools from the worker experience. They are now reached from Administrator → More, in development builds only.
- Placeholder SDS and toolbox documents.

## Unchanged, deliberately

- History, Scan and the bottom navigation: their goldens are byte-identical to 0.4.0+4.
- The measurement engine: REF-BLACK, thresholds and calibration are untouched. M0C and S1–S3 remain open.
- No ppm or ppm·h without a validated calibration.

## Not connected

- Organisation identity, server-side authorization, password recovery and Google sign-in.
- Central server and sync, and document libraries.

## Not verified on hardware

No physical phone was available.
