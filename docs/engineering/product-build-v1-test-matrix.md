# Product Build v1 — test and device matrix, known debt

## Tested (automated, Flutter test environment)

| Dimension | Covered |
|---|---|
| Widths | 320×568, 360×640, 390×844, 412×915, 430×932, 600×960, 800×1280, 844×390 landscape, 1280×800 landscape |
| Text scale | 100, 130, 150, 200 % (worker shell matrix); 100 and 200 % every route at 320 px |
| Safe area | Notch 59/34, gesture insets 24/16 |
| Touch targets | Navigation, central Scan, Home primary, sign-in, pre-use: ≥ 48 / 56 px at 320 px, 100 and 200 % |
| Rail vs bar | Every workspace: floating bar on phone, rail ≥ 720 px |
| Keyboard | Bar steps aside when the keyboard is up (existing foundation test) |

**Not tested:** any physical device; iOS device; Android 3-button navigation
on hardware; real camera permission prompts; real QR decoding from a
camera sensor; performance on low-end hardware.

## Test inventory (0.4.0+4)

App 1 052 · engine 312 · parity 394/394 · geometry drift 75.
UI recovery (0.4.0+4) added goldens for the splash at 320 px / 200 % text,
landscape and tablet; sign-in at 320 px; the DoseBand check and pre-use
outcomes (`test/golden/doseband_flow_golden_test.dart`); Home state B;
empty History; `test/auth/splash_test.dart`. 0.3.0+3 had App 1 038.
New suites: `test/operations/*` (store, registry, lifecycle, persistence,
§107 authorisation), `test/auth/auth_flow_test.dart`,
`test/doseband/*` (QR contract, pre-use rules, claim journey through the
UI), `test/hse/hse_workspace_test.dart`, `test/admin/admin_surface_test.dart`,
`test/foundation/touch_targets_test.dart`, `test/home/home_states_test.dart`.

## Known debt

| Severity | Area | Debt | Next action |
|---|---|---|---|
| High | Science | No validated calibration; M0C physical optical validation open | Colour print + phone; run M0C dossier |
| High | Platform | Not installed on a physical phone | Install APK; run the judge journey on hardware |
| High | Backend | No server: cross-device claim uniqueness, sync, central register, server-side authorisation | Build the API and relational schema; move claim to a DB transaction |
| Medium | Identity | Presentation accounts only; roles/scopes not editable | Connect organisation directory |
| Medium | Worker | No UI for a superseding re-read (service supports it) | Add re-read from a reference-failure result |
| Medium | Security | Local files not encrypted; audit log not tamper-evident | Encrypted store; hash-chained audit |
| Low | Reporting | PDF export not implemented | Add a PDF renderer |
| Low | UX | No connectivity indicator (nothing uses the network yet) | Add with sync |
| Low | UX | Pre-use photograph is not archived as evidence | Archive via the capture archive |
| Low | Legacy | Some governance screens use the older corporate components | Migrate to Phase 0 components |
| Low | UX | Home's primary action is below the first screen on a 390 × 844 phone (directive's card order); the centre Scan is always visible | Revisit order after device testing |
