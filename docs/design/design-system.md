# Design system

Status: specification. Phase 1 implements it.

## The governing idea

**The interface is chromatically neutral so that the measurement can be the only colour
on screen.**

This is not a stylistic preference. The user's task is judging a colour — the badge in the
viewfinder, the reference patches, the reacted sensor window. Simultaneous contrast and
chromatic adaptation are real: a saturated interface surrounding a badge image shifts how
that badge is perceived, and a warm-tinted "near-black" surface pulls the apparent hue of
everything beside it. An app that colours its own chrome freely is degrading the instrument
it claims to be.

So the surfaces are strictly neutral, the accent is placed far from the chemistry's own
colour trajectory, and saturation is spent only where it carries meaning.

Everything below follows from that, or from the product's second thesis: **a refusal is a
result, not an error.**

## Colour

### Neutral ramp — a step wedge

Surfaces are defined by equal steps of CIELAB **L\***, converted to sRGB with a\*=b\*=0.
Equal L* steps are equal *perceptual* steps, so the hierarchy reads evenly in bright sun and
in a dark tank area alike. Every value is exactly neutral (R=G=B). No tinted near-blacks.

| Token | L* | Hex |
|---|---|---|
| `neutral.00` | 100 | `#FFFFFF` |
| `neutral.02` | 98 | `#F9F9F9` |
| `neutral.04` | 96 | `#F3F3F3` |
| `neutral.08` | 92 | `#E8E8E8` |
| `neutral.14` | 86 | `#D7D7D7` |
| `neutral.26` | 74 | `#B6B6B6` |
| `neutral.42` | 58 | `#8B8B8B` |
| `neutral.58` | 42 | `#636363` |
| `neutral.70` | 30 | `#474747` |
| `neutral.80` | 20 | `#303030` |
| `neutral.86` | 14 | `#242424` |
| `neutral.91` | 9 | `#191919` |
| `neutral.95` | 5 | `#111111` |
| `neutral.100` | 0 | `#000000` |

True black is reserved for the camera viewfinder, where it is the correct surround for
judging a captured image. The dark-mode *scaffold* bottoms out at L*9 — pure black on OLED
smears during scroll and creates a contrast ratio that is fatiguing over a shift. A recessed
panel inside a card may go to L*5; it may never go to L*0. A test enforces this.

### Accent — instrument cyan

The chemistry runs white → yellow → brown → near-black (bismuth sulfide) or pale → dark
brown (copper sulfide). **The accent must not live anywhere in that path**, or the interface
competes with the reading and can bias it.

That puts the accent in the opposing region. Not a warm clay, not a violet.

| Token | Light | Dark |
|---|---|---|
| `accent` | `#0E6E7D` | `#4FC3D4` |
| `accent.muted` | `#D6EEF1` | `#123C44` |

### Status

Status colour never acts alone. Every status is carried by **icon + label + position +
colour** together, so it survives colour-vision deficiency, a sunlit screen and a greyscale
screenshot in an incident report.

| Token | Meaning | Light | Dark | Why |
|---|---|---|---|---|
| `status.valid` | The measurement can be trusted | `#0E6E7D` | `#4FC3D4` | **Not green.** Green means "safe", and this badge cannot tell anyone they are safe. Valid means the *instrument* is confident, not the *worker* is well. Conflating those is the false-reassurance failure the whole product exists to avoid. Valid therefore speaks in the instrument's own colour. |
| `status.warning` | Usable, with a caveat | `#8A5A00` | `#E0A73A` | An amber dark enough to hold 4.5:1 on light surfaces. |
| `status.censored` | Outside the quantifiable range | `#4A5C6A` | `#9BB0C0` | A cool slate. Not a failure and not a value — visually a third thing. |
| `status.refused` | No number may be reported | `#474747` | `#B6B6B6` | Neutral ink. A refusal is the instrument working correctly, so it does not get alarm colouring. |
| `status.simulated` | Not a real measurement | `#B5179E` | `#F06FDD` | Magenta, borrowed from the missing-texture convention in graphics. Deliberately unlike anything in the real product or the chemistry. It should look wrong, because it is not real data. |
| `status.destructive` | Irreversible action | `#A02114` | `#F0806F` | **Red appears nowhere else.** Not for refusals, not for high exposure. Reserving it means it still means something. |

A high exposure reading is rendered in `status.valid`, not in red. The number is the finding;
alarming it is the safety officer's interpretation, not the instrument's.

## Typography

One superfamily, two roles: **IBM Plex Sans** and **IBM Plex Mono**.

Chosen for three concrete reasons, not for flavour: it was drawn for an engineering company
and reads as technical without costume; it ships **Devanagari** in the same family, which a
Mangaluru deployment will need; and its mono is metrically companionable, so a readout and
its label sit together without fighting.

### Mono is semantic

**Monospace means "this value is measured or traceable."** Doses, uncertainties, badge IDs,
lot codes, model versions, timestamps, checksums.

It is never used for labels, headings, captions or chrome. A reader should be able to scan a
screen and know, from the letterforms alone, which values would appear in an audit record.

### Scale

Base 16px, ratio 1.25, snapped to whole pixels.

| Token | Size / line | Face | Use |
|---|---|---|---|
| `readout.hero` | 60 / 60 | Mono Medium | The dose. One per screen. |
| `readout.large` | 32 / 36 | Mono Medium | Secondary measured values |
| `readout.body` | 16 / 24 | Mono Regular | IDs, versions, timestamps |
| `readout.small` | 13 / 18 | Mono Regular | Dense traceability rows |
| `display` | 28 / 34 | Sans SemiBold | Screen titles |
| `heading` | 20 / 28 | Sans SemiBold | Section headings |
| `body` | 16 / 24 | Sans Regular | Default |
| `body.strong` | 16 / 24 | Sans Medium | Emphasis within body |
| `label` | 14 / 20 | Sans Medium | Field labels, buttons |
| `caption` | 13 / 18 | Sans Regular | Secondary detail |

Sentence case throughout. **No all-caps labels and no eyebrow labels.** A status reads
"Above range", not "ABOVE RANGE" — the interface is talking to a person at the end of a
shift, not stamping a form.

Line length caps at 68 characters for explanatory copy.

## Space and structure

4pt base grid. Steps: 4, 8, 12, 16, 24, 32, 48, 64.

Touch targets are **56pt minimum** in the worker flow, not 48. The user may be gloved, and
the cost of a mis-tap during badge closure is a corrupted coverage record.

Radii are restrained and meaningful rather than uniform: `0` for measurement surfaces and the
scale (an instrument face has square corners), `4` for controls, `12` for sheets and dialogs
that genuinely float. One radius on everything is the SaaS-card tell; here the radius tells
you whether a thing is a reading or a control.

Elevation is carried by the neutral ramp — a surface one step lighter, plus a hairline. No
soft grey drop shadows.

## The signature component: the measurement scale

This is where the design spends its boldness. Everything else stays quiet.

The dose is never a bare number. It is a point on a **printed scale that shows its own
limits** — the quantification limit at one end, saturation at the other, both drawn as hard
stops. The instrument displays the boundaries of what it can know, on every single result.

The axis is logarithmic, and intermediate ticks cull when their labels would collide. Both
limit labels are reserved before any tick is placed, because a scale whose purpose is showing
its own limits must never drop one. See ADR-0009.

**Valid**

```
  Valid                                    ✓

  3.2                                 ppm·h
  ± 0.8

  ├─────┬──────●────┬───────────────┤
 0.5    1    3.2   10              40
 LoQ                          saturation

  Coverage     7 h 52 min of 8 h
  Badge        DB-4K7M2
  Lot          L26-0912-A
  Model        cal-1.2.0
```

**Above range** — the marker leaves the scale rather than pinning to its end.

```
  Above range                              ↗

  > 40                                ppm·h

  ├─────┬───────────┬───────────────┤──▶
 0.5                               40

  The badge is saturated. The true exposure
  is at least 40 ppm·h and cannot be
  measured from this badge.

  Report to your safety officer and fit a
  new badge.
```

**Refused** — the readout slot is *held open and left empty*.

```
  No reading                               ⊘

  - - -                               ppm·h

  ├──────────────────────────────────┤

  The reference patches could not be read.
  Glare is covering the badge.

  Tilt the badge away from the light and
  scan again.
```

Those dashes are the point. The interface does not hide the readout when it fails, and it
does not fill it with a zero. It shows you the empty slot where a number would have been.
A worker who sees this knows something is missing; a worker who sees "0.0 ppm·h" does not.

**Amended during implementation.** The placeholder was originally specified as two em dashes.
At 60px an em dash fills its whole monospace cell, so consecutive ones tiled into a single
solid bar that read as a redaction or a progress indicator. Separated short dashes are also
what a laboratory balance or a multimeter shows when it has no value, so the meaning is
already familiar. Found by looking at the rendered output, not by reading the code.

Every non-valid state answers, in this order: **what happened · why it matters · what to do**
(directive §30). Never an error code alone.

## Motion

One orchestrated moment, at the transition from capture to result: the scale draws left to
right, then the marker settles into place. It takes 420 ms and happens once.

Everything else is state change only — a control responding to a press, a sheet opening, a
sync indicator advancing. No entrance animations on scroll, no hover transitions on cards.

`prefers-reduced-motion` removes the scale draw and places the marker directly.

| Token | Duration | Curve |
|---|---|---|
| `motion.instant` | 90ms | easeOut |
| `motion.control` | 160ms | easeOutCubic |
| `motion.surface` | 240ms | easeInOutCubic |
| `motion.reveal` | 420ms | easeOutQuint |

## Haptics

Semantic, never decorative. A worker in gloves may feel more than they see.

| Event | Feedback |
|---|---|
| Control pressed | selection click |
| Badge QR decoded | light impact |
| Auto-capture armed | light impact |
| Capture taken | medium impact |
| Result: valid | success notification |
| Result: censored or refused | warning notification |
| Destructive confirmed | heavy impact |

Valid and refused feel *different*. A worker should be able to tell a refusal from a reading
without looking.

## Accessibility floor

- Contrast 4.5:1 for all text, 3:1 for interface boundaries, in both themes.
- Status never conveyed by colour alone — icon, label, position and colour together.
- Full support to 200% text scale; the readout reflows rather than truncating.
- Every measured value has a screen-reader label including its unit and status, e.g.
  "3.2 ppm hours, plus or minus 0.8, valid" — never just "3.2".
- A refusal is announced as an assertive live region. It is the most important thing a
  worker can be told.
- Sunlight: the light theme's primary surface is `neutral.00` with `neutral.80` ink, which
  holds up at maximum brightness outdoors.

## The two registers (UI-SURFACE-01)

The product has five role surfaces — Worker, Safety, HSE, Reporting, Admin —
and they are **one application**. But they are not all the same kind of
surface, and the split matters scientifically rather than aesthetically.

### Corporate shell

Everything that frames the work: authentication, home, work context, safety,
HSE, reporting, administration.

| Token family | Source | Use |
|---|---|---|
| `primary` `primaryDeep` `primaryMuted` | `MrplCorporateColors` | Headers, navigation, primary actions |
| `accent` `accentMuted` | `MrplCorporateColors` | One emphasis per screen, never status |
| `surface` `surfaceMuted` `surfaceElevated` | `MrplCorporateColors` | Cards and page grounds |
| `CorporateRadii` sm 8 / md 12 / lg 16 / xl 22 | — | Chips, buttons, cards, sheets |

### Measurement instrument

The scanner, capture review, result and refusal surfaces, and the badge image
anywhere it appears.

These stay **chromatically neutral** and keep the `DoseBandColors` palette.
DoseBand measures colour; a saturated green or orange field next to a
colorimetric badge introduces simultaneous-contrast and chromatic-adaptation
effects in the eye of whoever is judging the capture. The rule is not a style
preference and is not negotiable for branding reasons.

`CorporateNavigationTheme` exists to hold this line in the one place the two
registers meet: it recolours navigation chrome for the corporate shells and
touches nothing else.

## Green does not mean safe

Restated here because this phase added five dashboards, which is exactly where
the rule erodes.

* Corporate green is **brand identity**. It appears in headers, navigation and
  primary actions.
* It must never encode *status*. A valid measurement means the instrument
  trusts the reading. It does **not** mean the exposure was safe.
* HSE metric tiles are deliberately uncoloured. A count of monitored workers is
  neither good news nor bad news, and a green dashboard invites "all clear,
  nothing to do" — the single most dangerous reading of a monitoring product.
* Attention is drawn by **ordering** and by the single accent edge on the one
  card that matters, not by a traffic-light palette.
* Red stays destructive-only.

## The register is carried, not remembered

`StepScaffold` takes a `StepRegister` — `corporate` or `instrument` — and
publishes it through `StepRegisterScope`. `DoseBandButton` reads it, so a
primary action is MRPL orange on a workflow screen and the instrument accent on
a measurement screen without any call site having to remember.

The default is `instrument`, because the measurement surfaces are where getting
this wrong costs more than looking untidy.

### Why the pre-work ticks stay teal

The pre-work checklist's ticks are the **instrument accent, deliberately not
green**, on an otherwise corporate screen.

A column of green ticks above a button, on the last screen before a worker
walks into a unit, is the single most likely place in this product for "all
green" to be read as "safe to work". The ticks mean *this requirement is
recorded*; they are not a verdict, and they are coloured so as not to look like
one.

## Data origin

Every corporate surface declares where its data came from, via `DataOrigin`:

| Origin | Chip | Meaning |
|---|---|---|
| `real` | Live | Real workflow, session or local store |
| `uiDemo` | Demo | `UiDemoCatalog` rows. No real worker, no real measurement |
| `notConnected` | Not connected | A future integration. No data exists |

Rendered by `OriginChip`, `DemoDataBanner` and `NotConnectedState`. All three
are neutral — there is deliberately no green "Live" chip, because the origin of
a number says nothing about whether the number is reassuring.

Provenance *within* a value (a PTW reference typed by hand versus confirmed by
a system) is a different concern and is carried by `EnterpriseValue` and
`ProvenanceChip`. See `docs/product/work-context.md`.

## Safety content has its own provenance

`DataOrigin` answers "is this row real?". `SafetyContentSource` answers a
sharper question for text a worker may act on: **who is telling me this?**

| Source | Chip | Meaning |
|---|---|---|
| `general` | General information | Widely published, not site-specific |
| `product` | DoseBand | A statement about this product |
| `organisation` | Organisation | Issued by the organisation. **Never authored here** |
| `publicStandard` | Public standard | Cited, not reproduced |
| `demo` | Demo | Demonstration content |
| `notConfigured` | Not configured | Not supplied, and not invented |

Rendered by `ContentSourceChip` in the *heading* of a `SafetySection`, so the
author is read before the content rather than after. Every chip is neutral,
including `organisation` — a green badge there would read as endorsement, and
the question being answered is authorship, not reassurance.

A test asserts nothing DoseBand authors is ever marked `organisation`. That is
the failure this model exists to prevent: generated placeholder copy wearing
the authority of a site procedure.

## Monospace, extended

The existing rule holds: monospace **means** the value is measured or
traceable, and is not a decorative choice. In the corporate surfaces that
covers identifiers and quantities — record IDs, badge and batch IDs,
calibration IDs, PTW and JSA references, doses, durations, timestamps and
version strings — and nothing else. A department name is not monospace.

## The absent-value placeholder

`Fmt.noValue` is `- - -`. One constant, used by the measurement readout, the
traceability rows, the workflow screens, the HSE register and the report
previews.

It means *not known*. It is never replaced by `0`:

* an unknown exposure window prints `- - -`, not `0 h 00 min`;
* a refused measurement prints `- - -`, not `0.0 ppm·h`;
* a record with no calibration prints `- - -`, not an estimate.

`0 min` is a legitimate value and means a window that has genuinely just
opened. The distinction between *zero* and *unknown* is the product.

## Role navigation

| Role | Pattern | Destinations |
|---|---|---|
| Worker | Bottom bar, always four | Home · Scan · Safety · History |
| HSE | Bottom bar, rail at ≥720 px | Overview · Monitoring · Exposures · Review |
| Reporting | Reached from HSE, sectioned index | — |
| Admin | Sectioned index | — |

The worker's four are a hard limit. PTW, JSA, badge, occupational health and
account are reached from the work they belong to: they are steps in a task, and
a task step promoted to a global destination loses its place in the sequence.
Account sits behind the header avatar.

Ten admin modules do not go in a bottom bar, so Admin and Reporting are
sectioned indexes rather than tabbed shells.

## Responsive and accessibility floor for the corporate surfaces

* Tested at 360, 390 and 430 logical pixels wide, and at a wide layout for the
  rail.
* Every surface renders at **200% text** with no overflow. The hero header
  sizes to its content for this reason — a fixed band clipped its own title.
* The hero keeps a solid corporate ground *under* the photograph, so white
  type still lands on dark green if the asset is missing or slow.
* Selection is never carried by colour alone: chips carry a check mark, cards
  carry a border and an indicator.
* Origin chips carry a full sentence in `Semantics`, so a screen-reader user
  gets the meaning rather than a word whose significance depends on having seen
  the legend.

## Imagery

`BrandAssets.refineryBackdrop` appears on landing surfaces only — splash,
sign-in header, Safety, HSE, Reporting and Admin heroes. Never behind a dense
table, where it costs legibility and buys nothing, and never on every screen,
which turns a strong image into wallpaper. Nothing is loaded from the network.


## What this system refuses to do

Recorded so it is not re-litigated at each screen: no purple or gradient washes, no
glassmorphism, no identical rounded cards, no decorative charts, no dashboard vanity
metrics, no medical-app visual language, no hazard stripes or alarm iconography, no
colour-only status, no green for valid, no red except for destructive actions, no all-caps
labels, no monospace for anything that is not a measured or traceable value.

---

## Decisions from UI-SURFACE-01-FINAL-AUDIT

Recorded here because they changed shared components, not single screens.

### Emphasis is neutral, never green

`InfoCard(emphasis: true)` draws `MrplCorporateColors.emphasisBorder` — neutral
ink at `Borders.emphasis` width — and never the corporate green.

It previously reused `selectedBorder`. The audit found that three of the four
emphasised cards in the product state an *absence*: "No production H₂S
calibration available", "No production calibration available", and a device's
untested validation state. In a safety product green conventionally means safe,
cleared or approved, so a green edge around those sentences read as an
endorsement of them.

`selectedBorder` keeps its green, because selection is a state the user put a
card into and carries no valence. Emphasis is the author saying *read this
first*, and in this product what must be read first is usually bad news. Weight
and contrast carry that; colour would editorialise it.

There is deliberately no new warning colour. Introducing one would replace a
false positive with a false alarm.

### The three absence words are distinct, and stay distinct

| Word | Meaning |
|---|---|
| **Not connected** | The integration or service exists conceptually; there is no live connection. |
| **Not configured** | A configuration value is expected and the organisation has not supplied one. |
| **Unavailable** | Data, evidence or a function cannot currently be provided. |

They are not synonyms and must not be normalised into one another. A single
outlier ("Not available") was folded into **Unavailable** during the audit; the
three-way distinction itself was left intact because it encodes more than a
uniform word would.

### DEMO and SIMULATED are different claims

- **DEMO** — fictional *organisational* data: a worker, a site, a department.
  Carried by `OriginChip(DataOrigin.uiDemo)` and `DemoDataBanner`.
- **SIMULATED** — a *quantity* that is not a real H₂S measurement. Carried by
  `SimulationMarker` and the magenta `statusSimulated`.

The magenta is reserved for the second meaning alone. A build-mode banner that
had borrowed it was re-styled during the audit: it is about which build is
running, not about measurement provenance, and letting the colour mean two
things would cost it the one meaning that matters.

### Titles carry the heading flag

The three shared scaffolds — `SafetyScaffold`, `StepScaffold`, `AuthScaffold` —
wrap their title in `Semantics(header: true)`. A title styled large is a heading
only to someone who can see it; the flag is what lets a screen-reader user reach
it. `/splash` is the one documented exemption.

### Flexible beside flexible in a header row

`Row(Expanded(name), StatusPill(...))` overflows at large text scales, because a
rigid child has no width to give back. Record-card headers make both children
flexible so the status label wraps. Labels wrap; they are never truncated — a
half-shown measurement state is worse than a two-line one.
