# UI foundation debt register

**Opened by APP-PRODUCT-01 Phase 0 · 2026-09-27**

What Phase 0 found and deliberately did **not** fix, because the directive
keeps legacy screens for their own vertical phases (§90). Debt listed here is
not permission to defer a Phase 0 blocker: none of these is a tested overflow,
an unreadable contrast on a shared component, broken navigation, or a
regression Phase 0 caused.

Where a guard exists, the number is locked by a ratchet in
`app/test/foundation/source_guards_test.dart`: it may fall, never rise.

Severity: **S1** misleads or excludes a user · **S2** visibly wrong or
inconsistent · **S3** hygiene.

## Visual

| # | Location | Problem | Sev | Phase | Why deferred |
|---|---|---|---|---|---|
| V1 | `home/presentation/home_cards.dart` — monitoring card | A large solid brand-green block (the former gradient, now one fill). With the green primary action directly beneath it, Home is greener than the v2 direction wants | S2 | P3 | Its white-on-green content has to be re-laid out, which is Home's redesign |
| V2 | Home hero (`HomeHero`) | Headline "**Safe People** / Sustainable Operations" — a corporate slogan, but the largest word on the first screen of an H₂S product is "Safe" (§97). **Flagged for a product decision.** | S1 | P3 | Copy is a product decision; the safety-language test matches phrases, not this slogan |
| V3 | Home hero at 320 wide, 200% text | "DoseBand" and "Petrochemicals" break mid-word in the two fixed-share columns | S2 | P3 | Hero layout is Home's; no overflow stripe |
| V4 | Worker identity card at 320 wide, 200% text | "No worker signed in" ellipsised to "No …" | S2 | P3 | Home component; name wrapping belongs with the P1 identity model |
| V5 | Home at ≥720 (rail layout) | Content stretches the full width; not capped at `Breakpoints.maxContentWidth` | S3 | P3 | Home layout |
| V6 | Auth: splash, sign-in, site/role cards | 7 gradient occurrences in 4 files; forest green `#082B20` field; dark composition | S2 | P1 | Authentication is rebuilt in P1; gradients are ratcheted |
| V7 | Legacy components (`InfoCard`, `SectionHeader`, `OriginChip`, `DemoDataBanner`, `NotConnectedState`, `CorporateErrorState`, `EmptyState`, `CorporateSearchField`, `StatusPill`) | Coexist with the v2 components (`ActionCard`, `StateView`, `ProductSearchField`, `ToneChip`) | S3 | P3–P9 | Each migrates with the screens that use it; they already read the v2 primitives |
| V8 | `SectionHeader` | All-caps section labels, which v2 sentence-case headings replace | S3 | P3–P9 | as V7 |
| V9 | HSE shell | Keeps its own four destinations (Overview · Monitoring · Exposures · Review) vs the target Overview · Exposures · Reviews · Reports · More | S3 | P7 | Target held as data in `WorkspaceDestinations.hse` |
| V10 | Admin / Reporting | Sectioned indexes, not workspace shells | S3 | P9/P11 | Target in `WorkspaceDestinations.admin` |

## Colour and gradient literals

| # | Location | Count | Phase | Why deferred |
|---|---|---|---|---|
| C1 | `auth/presentation/screens/splash_screen.dart` | 2 gradients, 13 `Color(0x…)` | P1 | Auth rebuild |
| C2 | `auth/presentation/screens/sign_in_screen.dart` | 1 gradient (shader mask) | P1 | Auth rebuild |
| C3 | `auth/presentation/widgets/selection_cards.dart` | 1 gradient, 9 `Color(0x…)` (painted site illustrations) | P1 | Auth rebuild |
| C4 | `auth/presentation/widgets/auth_background.dart` | 3 gradients, 6 `Color(0x…)` | P1 | Auth rebuild |
| C5 | `research/presentation/capture_diagnostics_screen.dart` | 5 `Color(0x…)`, 2 `Colors.<hue>` (diagnostic overlays) | P4 | Developer tooling; overlay colours are a measurement-surface decision |
| C6 | `capture/presentation/capture_screen.dart` | 2 `Colors.<hue>` (ROI guide on live preview) | P4 | Scanner rebuild; must stay chromatically neutral next to the badge |
| C7 | `workflow/presentation/prework_check_screen.dart` | 1 `Color(0x…)` | P2 | Pre-use check rebuild |

Gradients before Phase 0: **9** (in 5 files). After: **7** (in 4 files, all auth).

## Layout

| # | Location | Problem | Sev | Phase |
|---|---|---|---|---|
| L1 | `core/components/corporate.dart` `RecordRow` | Fixed 132-point label column; tight at 320 wide / 200% text | S2 | P7 |
| L2 | `features/scan/guided_scan_screen.dart` | Fixed 240×240 simulated target | S3 | P4 |
| L3 | `sign_in_screen.dart` (300-high band), `splash_screen.dart` (190-wide bar, `Spacer` proportions) | Fixed decorative geometry | S3 | P1 |
| L4 | 28 literal `fontSize:` values in 10 files (home cards, reporting register and traceability, exposure cell, capture, auth, HSE detail, safety components/scaffold) | Bypass the type scale | S3 | per screen's phase |

## Wall clock

18 files read `DateTime.now` directly (ratcheted, file by file). New code uses
`clockProvider`. Paid down file by file in the phase that owns each.

## Terminology and content

| # | Location | Problem | Phase |
|---|---|---|---|
| T1 | Worker journey, History empty state, HSE inventory, admin badge configuration, traceability | "Badge" in user-facing text where the product term is **DoseBand** | P2–P9 (per screen) |
| T2 | `ui_demo_catalog.dart`, `admin_demo_catalog.dart` | Six invented presentation names (Sunita Rao, Rahul Shetty, Priya Menon, Meera Nair, Joseph Fernandes, Imran Qureshi) predate §38; the set is frozen by a test | P7, P9 |
| T3 | `/select-role` | Free choice of any role — presentation behaviour on the production path | P1 |
| T4 | `/prework` "Ready for dosimetry" | Future wording is "DOSEBAND READY TO USE" (§97, §119) | P2 |
| T5 | `/scan` (Scan tab) | Stale copy: "The camera badge scanner is added in Phase 3" — a real camera path already exists for a physical band; the CTA "Assign / receive badge" uses the instrument accent on a product screen | P2/P4 |

## Data boundaries

| # | Location | Problem | Phase |
|---|---|---|---|
| D1 | Presentation data in four catalogs (`UiDemoCatalog`, `AdminDemoCatalog`, `ReportingDemoCatalog`, `SafetyDemoCatalog`) plus `SimulationCatalog` and `demo_account.dart` | Several sources rather than one replaceable boundary. `SimulationCatalog` (simulated measurements) is correctly separate from the organisational catalogs and must stay so | P10 (behind repository contracts) |
| D2 | HSE shell reaches badge inventory / batch | Inventory belongs to Admin (Class C) | P9 |
| D3 | `/reporting` | Identified registers and de-identified reports in one index | P11 |

## Assets

| # | Asset | Finding | Phase |
|---|---|---|---|
| A1 | `assets/images/MRPL Background.png` | 941×1672 PNG, **2.08 MB**. The same image as a quality-85 JPEG is **284 KB** (−86%). It is an approved brand asset, so it was not re-encoded in Phase 0 | P1 |
| A2 | `assets/images/MRPL Logo.png` | 317×316, 8 KB. Fine | — |
| A3 | Fonts | IBM Plex Sans (variable) + Mono: 809 KB bundled, deliberately (offline) | — |

Measurement evidence images are a separate domain and are never optimised by
UI asset work (§106).

## Dark theme

`DoseBandColors.dark`, `MrplCorporateColors.dark` and `ProductColors.dark`
still exist so the instrument goldens that render dark keep resolving. The
product ships light only (`ThemeMode.light`). Whether dark mode returns is a
product decision; if it does not, the dark palettes can be deleted with the
instrument dark goldens.
