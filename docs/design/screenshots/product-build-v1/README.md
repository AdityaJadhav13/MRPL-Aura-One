# Product Build v1 — screenshot index

Rendered from the golden tests at `8aa5355`/0.3.0+3 (Flutter test renderer,
IBM Plex, light theme, presentation dataset, clock pinned to 27 Sep 2026).
These are test renders, **not phone captures**: no physical device was
available in this run. Each was inspected by eye.

| Surface (§167) | File |
|---|---|
| Splash | `auth-splash-light.png` |
| Sign in | `auth-sign-in-light.png`, `auth-sign-in-refused.png`, `auth-sign-in-not-connected.png` (production), `auth-presentation-accounts.png` |
| Worker Home — no DoseBand (A) | `home-a-no-doseband.png` |
| Pre-use validation | covered by `test/doseband/claim_journey_test.dart`; no golden (camera) |
| Worker Home — monitoring (C) | `home-c-monitoring.png` |
| Final scan due (D) | `home-d-final-scan.png` |
| Completed (E) | `home-e-complete.png` |
| Untrusted clock | `home-attention-untrusted-clock.png` |
| History | `worker-history.png` |
| Profile | `worker-profile.png` |
| Supervisor overview / team / pipeline / exceptions / worker | `supervisor-*.png` |
| HSE overview / register / traceability / reports | `hse-*.png` |
| Management overview / monitoring / trends | `management-*.png` |
| Admin overview / people / inventory / band + QR label / system | `admin-*.png` |
| Safety | `safety-hub.png` |
| Development simulation entry | `worker-08-badge-assignment.png` |
| 200 % text, small phone (320) | `foundation-shell-home-320-text200.png`, `auth-sign-in-compact-large-text.png` |
| Large phone (430) | `foundation-shell-home-430.png` |
| Tablet / wide (rail) | `foundation-shell-home-rail-1280x800.png` |
| Landscape | `foundation-shell-home-landscape-844x390.png` |
| Offline state | none: the build has no connectivity detection and makes no network calls; every screen states records are on this device |
