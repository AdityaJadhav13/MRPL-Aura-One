/// The application version, single-sourced.
///
/// Stamped on every research capture record, so it must match the build that
/// produced the capture. `test/core/app_version_test.dart` fails if it drifts
/// from `pubspec.yaml`.
///
/// **Bump the build number for every APK that will touch a physical
/// specimen.** Two builds carrying the same version make their captures
/// indistinguishable, and a mid-session hotfix is exactly when that happens.
/// APP-INTEGRATION-01 §49.
const String appVersion = '0.4.0+4';
