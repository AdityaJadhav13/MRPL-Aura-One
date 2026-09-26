# DoseBand design system · v2

**APP-PRODUCT-01 · 2026-09-27 · supersedes the colour, radius and navigation
sections of [design-system.md](design-system.md).** Everything in v1 about the
instrument register, the measurement scale, monospace, the absent-value
placeholder, data origin and safety-content provenance still holds.

Implementation: `app/lib/core/design/` (tokens, colours, theme, breakpoints)
and `app/lib/core/components/`. Live reference: the development-only
**component catalog** at `/dev/components`. Regression images:
`app/test/golden/goldens/foundation-*.png`.

---

## 1. Principles

1. **White-first.** White page, white cards, hairline borders. Colour is
   spent on what the user can do and on what a state means.
2. **Brand is not status.** The brand green marks the primary action and the
   selected destination. It never means valid, complete, safe or good.
3. **Refuse rather than decorate.** No gradients, no glow, no glass, no
   decorative motion.
4. **Two registers.** Product chrome takes the brand. Measurement surfaces stay
   chromatically neutral (§92) — the eye judges colour against its surround.
5. **Legible in a plant.** 16-point body, ≥4.5:1 text, 56-point targets for
   worker-critical controls, usable at 200% text.
6. **One source.** A hex value exists once, in `tokens.dart`. A breakpoint
   exists once, in `Breakpoints`. A state has one component.

## 2. Palette

### Brand — derived, not invented (§9)

The anchor is the field green of the approved logo asset
`assets/images/MRPL Logo.png`: **`#5C822D`** (the most frequent pixel; CIELAB
L\*50 a\*−28 b\*+41). The ramp keeps that hue and moves only in L\*.

These are MRPL-*inspired* values sampled from a supplied asset. No official MRPL
brand standard has been seen; nothing here claims to be one, or claims MRPL
endorsement.

| Token | Hex | Role | Contrast |
|---|---|---|---|
| `brandPrimary` | `#527823` | Primary actions, selected navigation, links | 5.16:1 on white; white on it 5.16:1 |
| `brandPrimaryPressed` | `#416318` | Pressed primary; focus ring | 6.95:1 on white |
| `brandPrimaryContainer` | `#EAF0E0` | Selected fill, nav indicator | — |
| `onBrandContainer` | `#416318` | Text/icons on the container | 5.97:1 on `#EAF0E0` |
| `brandSubtle` | `#F4F8EE` | A whole selected row | — |
| `brandMark` | `#5C822D` | The logo's own green. Identity marks only | 4.48:1 (not for text) |
| `brandSecondary` | `#D96E0C` | MRPL-inspired orange at the 3:1 step. Thin rules, small marks | 3.39:1 (never text) |
| `Brand.orange` | `#E87B1E` | The original orange. Non-meaningful decoration only | 2.88:1 |

**Replaced:** the v1 corporate primary `#0E4634` (a dark forest green that
matched a mockup, not the logo) and the v1 primary action — **white text on
`#E87B1E`, 2.88:1**, on the button a gloved worker reads in sunlight.

### Surfaces, borders, text

| Token | Hex | Use |
|---|---|---|
| `surfacePage` | `#FFFFFF` | Screen ground |
| `surfaceCard` | `#FFFFFF` | Cards |
| `surfaceSecondary` | `#F3F3F3` | Recessed areas, search fill, disabled fill |
| `borderSubtle` | `#E8E8E8` | Card edges, dividers |
| `borderDefault` | `#D7D7D7` | Outlined buttons, chips |
| `borderInput` | `#8B8B8B` | Field outlines (3.41:1 — a control boundary) |
| `textPrimary` | `#242424` | 15.5:1 |
| `textSecondary` | `#636363` | 6.0:1 |
| `textDisabled` | `#767676` | 4.54:1 — quieter, still readable |
| `scrim` | `#000000` @ 70% | Solid scrim over photographs. Never a gradient |

Neutrals are exact greys (R=G=B) from the v1 step wedge, so the two registers
share them.

### Semantic (status) colours

| Token | Hex | Container | Means |
|---|---|---|---|
| `instrumentAccent` | `#0E6E7D` | `#E3F2F4` | The instrument speaking: a measured state |
| `simulationAccent` | `#B5179E` | `#FBEAF8` | SIMULATED. Nothing else |
| `warning` | `#8A5A00` | `#FDF3E1` | Needs a person: review required, retake |
| `critical` | `#A02114` | `#FBEAE8` | A genuine failure or destructive action |
| `info` | `#4A5C6A` | `#EEF1F3` | Offline, not connected, unavailable |

Every pair holds ≥5:1. **There is no success, safe, ok or positive token**, and a
test fails if one is declared.

## 3. Green is not safe (§10)

- The brand green is never a status tone. `StatusTone` has no green member,
  and a test asserts no tone resolves to a brand colour.
- A snack bar is neutral ink, never a green toast.
- Red is not used for a refusal to calculate, a high reading, or any
  measurement state; only for genuine failure or destruction.
- "Ready" refers to the DoseBand ("DOSEBAND READY TO USE"), never the
  atmosphere.

## 4. Typography

IBM Plex Sans (interface) and IBM Plex Mono (measured or traceable values),
bundled — no runtime font fetch. The scale is unchanged from v1; its roles:

| Role | Token | Size / line |
|---|---|---|
| Display / hero | `display` | 28 / 34, 600 |
| Page title (app bar) | `heading` | 20 / 28, 600 |
| Section title | `bodyStrong` | 16 / 24, 500 |
| Card title | `bodyStrong` | 16 / 24, 500 |
| Body | `body` | 16 / 24, 400 |
| Secondary body | `caption` in `textSecondary` | 13 / 18 |
| Label | `label` | 14 / 20, 500 |
| Caption | `caption` | 13 / 18, 400 |
| Measurement numeric | `readoutHero` / `readoutLarge` | 60 / 60 · 32 / 36, mono |
| Traceability | `readoutBody` / `readoutSmall` | 16 / 24 · 13 / 18, mono |

**Change:** the app-bar title moved from `display` (28) to `heading` (20). A
28-point title was the first thing to wrap or clip at 200% text.

Text scaling is never disabled. The one clamp is navigation labels, which stop
growing at 130% (they would otherwise not fit five across 320 points) — the
screen content scales fully.

## 5. Spacing

A 4-point grid (`Space`): 4 · 8 · 12 · 16 · 24 · 32 · 48 · 64. Semantic names
(`Gaps`):

| Gap | Value |
|---|---|
| `screenGutter` | 16 |
| `section` | 24 |
| `cardPadding` | 16 |
| `control` | 12 |
| `labelToValue` | 4 |

Bottom-navigation clearance is structural, not a padding value: the floating
bar lives in the scaffold's bottom slot, so content cannot scroll under it.

## 6. Radii

One scale (`Radii`): **0** measurement surfaces · **4** instrument controls ·
**8** product controls (buttons, fields, chips) · **12** cards · **16** things
that float (sheets, dialogs, the navigation bar) · **pill** status chips only.
`CorporateRadii` survives as aliases; its 22-point `xl` is retired.

## 7. Elevation

Surfaces separate by contrast and a hairline. Two shadows exist, both neutral
black at low alpha: `Elevation.floating` (the navigation bar) and
`Elevation.overlay` (sheets, dialogs). No tinted or glowing shadows. Material's
surface tint is off (`surfaceTint: transparent`).

## 8. Buttons

`DoseBandButton` is the one button, for both registers.

| Variant | Look | Use |
|---|---|---|
| `.primary` | Filled brand (product) / instrument accent (measurement) | The one dominant action per screen |
| `.secondary` | Outlined, neutral | Subordinate actions |
| `.tertiary` | Text only | Low-emphasis navigation |
| `.destructive` | Outlined red | Irreversible actions only |

States: default, pressed (ink), focused, disabled (readable grey), **loading**
(spinner in place of the icon, label unchanged, taps ignored, announced "…,
in progress"). Height ≥56. Icon buttons have tooltips and ≥48 targets.

The register (brand vs instrument) comes from the nearest `StepRegisterScope`;
`ProductPage` and corporate `StepScaffold`s publish the product register.

## 9. Inputs

`ProductTextField` (label, hint, helper, error, disabled, read-only, loading) ·
`ProductSearchField` (labelled for screen readers; only where it queries real
data) · `ProductDropdownField` · `ReadOnlyField` (company-authoritative values,
with provenance; absent value prints `- - -`). Labels are never placeholders.
Errors say what is wrong and how to fix it, and wrap to three lines.

## 10. Cards

| Pattern | Component |
|---|---|
| Standard information | `InfoCard` (legacy, v2 tokens) |
| Action | `ActionCard` |
| Status / exception | `StatusBanner` (tone from the status vocabulary) |
| Measurement | `ResultCard` (instrument register, unchanged) |
| Identity | `IdentityHeader` / `IdentityAvatar` |
| Empty / state | `StateView(compact: true)` |

`InfoCard(emphasis: true)` keeps its **neutral** emphasis edge (UI-SURFACE-01
decision, preserved).

## 11. Status semantics

`ProductStatus` — every status has a word, an icon and a tone:

| Status | Tone |
|---|---|
| Active | info |
| Complete, Pending, No reading, Unsupported calibration | neutral |
| Review required, Invalid, Retake, Result unreliable | attention |
| Offline, Sync pending, Unavailable, Not connected | info |
| Simulated | simulated |
| Below quantification, Above range, Saturated | instrument |

Domain lifecycles pass qualified labels ("Monitoring complete", "DoseBand
read", "Record reviewed") so "Complete" never means two things.

## 12. States (§22)

`StateView(kind: StateKind…)`: loading · empty · noResults · offline ·
serverUnavailable · permissionDenied · notConnected · notConfigured ·
unavailable · error. Each is distinct in title, icon and meaning; there is no
"Something went wrong". Full-screen states centre and scroll; compact states
sit in a card.

## 13. Provenance

`RecordProvenance` is the one vocabulary: on this device · synced ·
presentation data · simulated · manual entry · organisation system · not
connected · unavailable. Every earlier provenance type maps into it
(`provenance_mapping.dart`). `ProvenanceChip` renders it. Presentation data is
declared once per screen; **simulated quantities are always marked on the
value**. Synced and organisation-verified cannot be produced today.

## 14. Navigation

**Worker:** Home · History · **Scan** · Safety · Profile — `FloatingNavigationBar`:
white surface, hairline, one neutral shadow, 16 radius, inside the system
insets with an 8-point floating gap. Scan is a filled brand circle in the
centre; other destinations are neutral until selected (brand on a pale pill
indicator). Every destination ≥56×56. Labels always shown. Selection is
announced (`selected`, `button`, mutually exclusive).

Scan is a destination, not a workflow: the Scan screen resolves new band /
active / final read from state (§58).

**Adaptive:** below 720 the bar; at 720 and wider a `NavigationRail` with the
same destinations and the same selected index, so the selection survives
rotation. The keyboard hides the bar.

**Other workspaces:** target destination sets are data in
`WorkspaceDestinations` (Supervisor, HSE, Management, Admin); not wired in
Phase 0.

## 15. Responsive rules

| Class | Width | Layout |
|---|---|---|
| compact | < 600 | Single column, bottom bar, cards |
| medium | 600–719 | Bottom bar, content capped at 720 and centred |
| expanded | ≥ 720 | Rail; dense data may become a table |

Screens ask `WindowClass.of(context)` or `WindowClass.forWidth(constraints)`.
No screen owns a breakpoint. `AdaptiveRecordList` is cards on a phone and a
table when wide. Layouts use `Flexible`, `Wrap`, `LayoutBuilder` and scrolling
— never a scale transform, never clipping to hide overflow.

**Tested matrix:** 320×568 · 360×640 · 390×844 · 412×915 · 430×932 · 600×960
· 800×1280 · 844×390 landscape · 1280×800 landscape, each at 100/130/150/200%
text, with status-bar and gesture insets. **Supported design range:** 320–1280
logical points wide, portrait and landscape, up to 200% text. This is the
tested range, not a claim about every device.

## 16. Accessibility

Page titles are headings (`ProductPage`, `StepScaffold`, `SafetyScaffold`,
`AuthScaffold`). Buttons announce label and state. Decorative images are
excluded. Status and provenance chips carry full sentences for screen
readers. Flutter's tap-target, labelled-target and text-contrast guidelines
run on the catalog sections. Reduced motion disables the navigation indicator
animation.

## 17. Imagery

Refinery photography only on authentication and a few landing heroes (Home,
Safety, HSE, Reporting, Admin); never behind a measurement value or a dense
table. Over a photograph: a **solid** translucent scrim (`scrim`), never a
gradient, and never a green wash. A solid neutral ground sits under every
photograph so white text survives a missing asset. No network images.

## 18. Dialogs, sheets, messages

Dialog: one yes/no about one action; confirm names the action, cancel keeps
the user where they were, destructive confirm drawn destructive
(`showConfirmDialog`). Sheet: a short choice or explanation. Full screen:
anything with steps or several fields — every worker-critical flow. Snack bars
(`showProductMessage`) only for transient outcomes; never for a measurement
result.

## 19. Motion

Only where it communicates state (the nav indicator, 160 ms). No bounce,
no decorative page transitions, no long splash. `MediaQuery.disableAnimations`
is honoured. The ripple is `InkRipple`, not the more expensive sparkle.

## 20. Theme

Light only (`ThemeMode.light`). Material 3. Every Material component used by
the product is themed from tokens (buttons, fields, chips, dialogs, sheets,
snack bars, menus, list tiles, checkboxes, radios, switches, progress,
tooltips, navigation bar and rail). Default `primary` is the brand;
`InstrumentTheme` re-maps it to the instrument accent on measurement routes and
instrument `StepScaffold`s.

## 21. Anti-patterns

- **NO GRADIENTS.** Ratcheted by a test; 7 legacy occurrences remain, all in
  authentication (P1).
- **NO DARK-GREEN-DOMINATED SCREENS.** No full-bleed green surfaces, no green
  washes over photographs.
- **NO GREEN = SAFE SEMANTICS.** No green status, no green toast, no "safe".
- **NO RANDOM HEX COLOURS.** Literals outside `core/design/` are ratcheted.
- **NO RANDOM CARD RADII.** One scale.
- **NO RANDOM DEMO CHIPS.** Presentation data is declared once per screen.
- **NO FAKE COUNTERS.** No count without a data source.
- **NO FAKE CONNECTED/SYNCED STATES.** `synced` and `organizationIntegration`
  are unproducible today, and tested so.
