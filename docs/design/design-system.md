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

## What this system refuses to do

Recorded so it is not re-litigated at each screen: no purple or gradient washes, no
glassmorphism, no identical rounded cards, no decorative charts, no dashboard vanity
metrics, no medical-app visual language, no hazard stripes or alarm iconography, no
colour-only status, no green for valid, no red except for destructive actions, no all-caps
labels, no monospace for anything that is not a measured or traceable value.
