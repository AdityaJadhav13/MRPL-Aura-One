# Authentication flow

**Phase AUTH-UI-01. UI and navigation only.**

> **No identity verification occurs anywhere in this flow.** Sign-in checks that
> required fields are non-empty and advances. Nothing is sent anywhere, no
> credential is checked against anything, and every session produced is marked
> `AuthSource.demo`.

---

## 1. Screens

```
/splash  ──▶  /sign-in  ──▶  /select-site  ──▶  /select-role  ─┬─▶  /home  (worker shell)
                                                                └─▶  /workspace/:role  (placeholder)
```

| Route | Screen | |
|---|---|---|
| `/splash` | `SplashScreen` | Corporate identity over a painted refinery backdrop. Advances itself after ~1.5 s. |
| `/sign-in` | `SignInScreen` | Employee / Contractor, demo credentials, gate-pass placeholder. |
| `/select-site` | `SiteSelectionScreen` | Work location, from a typed repository. |
| `/select-role` | `RoleSelectionScreen` | Application role. |
| `/workspace/:role` | `RoleWorkspacePlaceholder` | Where a role with no interface lands. |

Back navigation is go_router's default. The four screens are independent
locations rather than a wizard, so returning to an earlier step preserves
whatever was chosen — selections live in `AuthController`, not in screen state.

## 2. Two visual registers, and the line between them

DoseBand now has two palettes, deliberately.

| Register | Where | Theme extension |
|---|---|---|
| **Corporate shell** | splash, sign-in, site/role selection, identity | `MrplCorporateColors` |
| **Instrument** | capture, result, measurement readouts, scale | `DoseBandColors` |

**The measurement surfaces stay chromatically neutral**, and that is a
measurement requirement rather than a style preference: the eye judges colour
relative to its surroundings, so a saturated green frame around a
green-shifting colorimetric badge is an invitation to misread it. The corporate
palette must not spread into the capture or result screens.

The separation is enforced by having two extensions rather than one. Corporate
widgets read `context.corporate`; instrument widgets read `context.colours`.
Nothing under `features/capture/` or `features/result/` reads the corporate
palette, and `DoseBandColors` was not modified by this phase.

Corner radii are split for the same reason: `Radii` (instrument, square
corners) and `CorporateRadii` (shell, moderate radius).

### Token provenance

`MrplCorporateColors` values are **MRPL-inspired prototype tokens**, sampled
from the approved design mockup. **No published MRPL brand standard has been
verified.** They are documented as provisional in the source and must be
replaced if real brand values are supplied.

## 3. Assets and their provenance

| Asset | Source | Used by |
|---|---|---|
| `assets/images/MRPL Logo.png` | **Supplied by the project owner** | `MrplBrandmark` — splash and every corporate header |
| `assets/images/MRPL Background.png` | **Supplied by the project owner** | Splash backdrop; sign-in header band at 30%; Mangalore Refinery site thumbnail |
| Site thumbnails | Photograph where one is supplied, else a painted scene per `SiteKind` | `SelectableSiteCard` |
| `RefinerySkyline` | Painted `CustomPainter` | Fallback only; no longer used in the flow |
| Footer skyline | Painted inside `CorporateFooterWave` | Site and role selection |

Paths live in `BrandAssets` so a rename is one edit and no widget carries a
string literal pointing at a binary.

### Site thumbnails

`Site.imageAsset` is a nullable slot. Where it is set, `_SiteThumbnail` renders
the photograph; where it is null it falls back to `_SiteIllustration`, a
`CustomPainter` that draws a flat scene for the site's `SiteKind`.

Only **Mangalore Refinery** currently carries a photograph, reusing the
supplied backdrop. Corporate Office, MRPL Retail (HiQ) and Projects Site are
painted, and **three more photographs are still needed from the project owner**
to finish this screen. Nothing was downloaded to fill the gap: a painted scene
is visibly a drawing and cannot be mistaken for a photograph of a real MRPL
location, which a stock image of some other refinery could be.

The office scene is drawn as a window **grid** — mullions in both directions —
rather than horizontal floor bands alone, because bands alone read as ruled
paper at 74 x 86 px. The footer skyline is drawn from many narrow elements
rather than a few wide ones for the same reason: wide blocks in a row under a
card list containing "Reports and dashboards" read as a bar chart.

The logo asset is a square with its own solid green field running edge to edge
— verified by decoding its palette — so it is **clipped, not inset on a
plate**. Padding it onto a white card printed a keyline the mark does not have.

`MrplBrandmark.placeholder()` still draws the neutral monogram, kept for any
context where the licensed asset is unavailable, so the widget degrades rather
than throwing.

**There is no network image anywhere in this flow.** Both assets are bundled,
which is what lets the whole flow work with no connectivity — a hard
requirement for a plant with no signal.

## 4. What is demo, and what is real

### Real

- Navigation between all five destinations.
- Typed state: `AuthState`, `AuthSession`, `Site`, `AppRole`, `DemoIdentity`.
- Form validation (required fields).
- Selection state, disabled/enabled Continue, password visibility.
- Responsive layout and accessibility semantics.

### Demo

- **Sign-in.** `DemoAuthRepository` checks field emptiness and returns
  `DemoAuthAccepted` with an identity marked `AuthSource.demo`. The type is
  named `DemoAuthResult`, not `AuthResult`, so a later reader cannot mistake it.
- **The site list.** Prototype seed configuration in `SeededSiteRepository`,
  describing locations MRPL is publicly associated with. **Not fetched from any
  MRPL system**, not a directory, and not authoritative.
- **Roles.** Application role modelling. They map to no identity provider and
  grant nothing; no authorisation is enforced anywhere.

### Password handling

The password is passed to the repository, checked for emptiness, and dropped.
It is **not** stored on the identity, the session or the state; not logged; not
persisted; not sent anywhere. The field is cleared on successful submission. A
test asserts the password appears in neither the session nor the widget tree.

"Remember me" is a UI control only in this phase — nothing is remembered,
because there is no session to persist yet.

## 5. The development skip control

Small, tertiary, bottom-right, on all four screens.

```dart
AuthDemoConfig.fromEnvironment(config).allowSkip  // == config.simulationAvailable
```

It is derived from `EnvironmentConfig.simulationAvailable`, which is already
`false` in production by construction, rather than from a second independent
flag. One fact about the build switches off both simulated measurements and the
authentication bypass; two flags could disagree.

Screens do not render the control at all when the flag is false — the widget
does not check the flag itself, because a control that decides its own
visibility is one refactor away from deciding wrongly.

Skipping produces an obviously synthetic identity — `DEMO-USER` / `Demo User`,
`AuthSource.demo` — and lands on the worker shell. It never quietly fabricates
something that reads like a real employee record.

**Tested:** the skip control is asserted present on all four screens in a
development build and **absent on all four in a production build**.

## 6. Role model

| Role | Workspace |
|---|---|
| Worker | The existing worker shell |
| HSE Officer | Placeholder |
| Supervisor | Placeholder |
| Management | Placeholder |
| Administrator | Placeholder |

Only the worker journey exists. The others reach
`RoleWorkspacePlaceholder` — a finished-looking screen that says nothing is
finished — rather than being dropped into the worker UI, which would show
someone an interface built for a different job and let them believe it was
theirs.

## 7. Accessibility

- Selection cards expose `button` + `selected` and declare their own tap
  action; children are excluded so a card announces once.
- Selection is never conveyed by colour alone: the indicator changes **shape**
  (empty ring → filled check) as well as colour, and the border weight changes.
- Password visibility is a labelled button announcing "Show password" /
  "Hide password"; the field carries `obscured`.
- The skip control is visually small but keeps a 84×40 target.
- **The brandmark does not scale with the reader's text setting.** It is a
  logo, and it is an image; the monogram fallback overflowed its plate at 200%
  before this was fixed.
- The splash's two text blocks sit on very different parts of the photograph,
  so they are coloured differently — deep green on the pale sky, white on the
  darkened foreground. A single colour would fail on one of them. A light
  scrim over the sky and a corporate-green sink over the foreground hold the
  contrast whatever the photograph does.
- The "Remember me" / "Forgot password?" row reflows to two lines rather than
  truncating at large text scales.
- Every screen scrolls; the sign-in card rides above the keyboard.
- Verified at 360 / 390 / 430 logical widths and at 150% and 200% text.

## 8. Motion

Splash fades in over 620 ms and honours `MediaQuery.disableAnimationsOf`.
Selection and segment changes are 160 ms. Nothing loops, bounces or parallaxes.

## 9. Integration placeholders — all NOT CONNECTED

| | Status | What happens today |
|---|---|---|
| MRPL identity / directory | **NOT CONNECTED** | Field-emptiness check only |
| Gate Pass QR | **NOT CONNECTED** | Tapping says so |
| SSO / LDAP / SAP | **NOT CONNECTED** | No entry point |
| Password recovery | **NOT CONNECTED** | Tapping says so |
| Role → IAM mapping | **NOT CONNECTED** | Roles grant nothing |
| Site directory | **NOT CONNECTED** | Seeded prototype list |
| Session persistence | **NOT CONNECTED** | In-memory; "Remember me" remembers nothing |

No screen in this flow claims a connection it does not have, and none of the
prohibited phrasing ("Official", "Approved", "Certified", "Connected to MRPL",
"Verified by MRPL") appears anywhere.

## 10. Deviations from the approved mockup

| Mockup | Here | Why |
|---|---|---|
| Site photo thumbnails | Photograph for Mangalore Refinery; painted scenes for the other three | Only one site photograph has been supplied |
| Colour illustrations for each role | Filled single-colour glyphs, worker in `accent` | Drawing five characters by hand would be worse than a clean glyph, and no illustration set was supplied |
| Determinate progress bar | Indeterminate | The work's duration is genuinely unknown; a fake percentage was avoided in the previous launch screen for the same reason |
| "Access your MRPL account" | "Access your DoseBand workspace" | There is no MRPL account to access |
| "you agree to MRPL IT Security Policy" | "Access is subject to organization security and acceptable-use requirements." | Naming a specific MRPL policy would invent legally binding wording |
| — | `DEMO` badge on the sign-in card | The prototype must say what it is |
| Four roles pictured | Five (Management included) | It was in the mockup and fits the role model |
