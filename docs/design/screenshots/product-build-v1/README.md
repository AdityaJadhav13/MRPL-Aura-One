# Product Build v1 — screenshot index

Rendered from the golden tests at 0.4.0+4 (UI recovery; Flutter test
renderer, IBM Plex, light theme, presentation dataset, clock pinned to
27 Sep 2026). These are test renders, **not phone captures**: no physical
device was available. Each was inspected by eye.

## Recovered (corrective directive §3)

| Surface | File |
|---|---|
| Splash | `auth-splash-light.png`; `auth-splash-320-text200.png`, `auth-splash-landscape-844x390.png`, `auth-splash-tablet-800x1280.png` |
| Sign in / role entry | `auth-sign-in-light.png`, `auth-sign-in-320.png`, `auth-sign-in-compact-large-text.png`, `auth-sign-in-refused.png`, `auth-sign-in-not-connected.png` (production), `auth-presentation-accounts.png` (role cards) |
| Worker Home — no DoseBand (A) | `home-a-no-doseband.png`, `home-a-work-recorded.png`, `foundation-shell-home-390.png` |
| Worker Home — assigned (B) | `home-b-assigned-simulated.png` (development simulation only; a real claim starts monitoring in the same step) |
| Worker Home — monitoring (C) | `home-c-monitoring.png` |
| Worker Home — final scan due (D) | `home-d-final-scan.png` |
| Worker Home — complete (E) | `home-e-complete.png` |
| Untrusted clock | `home-attention-untrusted-clock.png` |

## Preserved (byte-identical goldens before and after the recovery)

| Surface | File |
|---|---|
| History populated / empty | `foundation-shell-history-390.png`, `worker-history.png` / `history-empty.png` |
| Scan (contextual tab) | `foundation-shell-scan-390.png` |
| Safety | `foundation-shell-safety-390.png`, `safety-hub.png` |
| Profile | `foundation-shell-profile-390.png`, `worker-profile.png` |
| Five-item floating navigation | every `foundation-shell-*` render |

## DoseBand flow

| Step | File |
|---|---|
| Scanned band, before the photograph | `doseband-check.png` |
| Pre-use READY / CANNOT VERIFY / REPLACE | `doseband-pre-use-ready.png`, `doseband-pre-use-cannot-verify.png`, `doseband-pre-use-replace.png` |
| Final scan, wrong band refused | `doseband-final-scan-wrong-band.png` |
| Final camera | none: needs a camera; covered by `test/doseband/claim_journey_test.dart` with a fake camera port |
| Result / refusal | `app/test/golden/goldens/result-screen-*.png` (unchanged) |

## Other workspaces (unchanged in this run)

| Surface | File |
|---|---|
| Supervisor overview / team / pipeline / exceptions / worker | `supervisor-*.png` |
| HSE overview / register / traceability / reports | `hse-*.png` |
| Management overview / monitoring / trends | `management-*.png` |
| Admin overview / people / inventory / band + QR label / system | `admin-*.png` |

## Sizes

| Dimension | File |
|---|---|
| Small phone 320 at 200 % text | `foundation-shell-home-320-text200.png`, `auth-splash-320-text200.png` |
| 360 | `foundation-shell-home-360.png` |
| Large phone 430 | `foundation-shell-home-430.png` |
| Tablet / wide (rail) | `foundation-shell-home-rail-1280x800.png`, `auth-splash-tablet-800x1280.png` |
| Landscape | `foundation-shell-home-landscape-844x390.png`, `auth-splash-landscape-844x390.png` |
| Offline | `foundation-state-offline-in-shell.png` is the component state. The build has no connectivity detection and makes no network calls, so no screen ever enters it. |
