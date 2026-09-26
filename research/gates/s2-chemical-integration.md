# GATE S2 — Chemical integration validity

**Status:** OPEN — blocking the ppm·h claim
**Owner:** chemistry
**Decides:** whether a candidate chemistry integrates exposure, or merely detects H₂S
**Raised by:** finding F-2, `research/measurement-engine-audit.md`

---

## 1. The question

A dosimeter must **remember**. Its endpoint state has to encode everything the
badge was exposed to over the shift, and it has to still encode it at the
moment the phone photographs it — which may be an hour after the worker left
the unit.

Most of the best-performing smartphone H₂S chemistries in the literature do
not do this. They equilibrate with the current concentration and forget.

> **A chemistry does not qualify for DoseBand merely because it detects H₂S.**

This gate exists because that sentence is easy to agree with and easy to
violate: the natural way to choose a chemistry is to read the H₂S sensing
literature and pick the one with the best reported LOD, and every high-scoring
candidate found so far fails on retention.

## 2. The evidence that makes this a gate, not a checklist item

### Engel et al. 2021 — reversible

Printed sensor labels for NH₃, HCHO and H₂S; QR-like code with integrated
colour reference spots; H₂S detected by an immobilised **copper(II) azo dye
complex**. Architecturally the closest published thing to DoseBand.

Kiwfo et al. 2024 (`research/papers.md` P1), describing it:

> "In the cases of detection of NH₃ and H₂S, the indicator reactions are
> **reversible**. Therefore, only the momentary response to varying gas
> concentrations is obtained (and not the commonly achieved time-weighted
> values of passive sampling devices)."

### QRsens (Escobedo et al. 2023) — equilibrium

> "The exposure time for the tests was 2 min, time enough to prepare the
> standard analyte/nitrogen mixture and **to reach the equilibrium**."

Range 0.01–0.6 ppm, reported as concentration. A sensor that equilibrates in
two minutes has, by construction, no memory of the preceding eight hours.

### Carpenter et al. 2017 (Cu-PAN) — unresolved

Cu-PAN reacts with H₂S to form CuS, which is extremely insoluble — promising
for retention. But the paper also states that the coloured product is
dissolved by HCl generated in the reaction itself, and its concluding remarks
note that "copper is not the only metal shown to bind **reversibly** with PAN".

The paper never runs a retention experiment: exposures are short (seconds to
minutes) into a fixed 1.35 L volume, and readings are taken promptly.

**So retention is unknown for the closest H₂S chemistry we have data on.** Not
disproved — unmeasured. That is exactly the state this gate exists to end.

## 3. Classification scheme

Every candidate chemistry is classified into one of four states. The
classification lives in this document and is mirrored in the schema
(`formulations.reversibility_class`).

| Class | Meaning | Qualifies for DoseBand? |
|---|---|---|
| **IRREVERSIBLE / RETAINED** | The colour change persists after the analyte is removed, within the read-by window, within the climate envelope. | Yes, subject to S2-E2…E5 |
| **REVERSIBLE** | The response tracks current concentration and decays when the analyte is removed. | **No.** Not a dosimeter. |
| **CONDITION-DEPENDENT** | Retained under some conditions (e.g. dry) and not others (e.g. >70 % RH). | Only with a validated environmental domain, and with `ENVIRONMENT_OUTSIDE_VALIDATED_RANGE` enforced. |
| **UNKNOWN** | Not tested. | **No**, and it must not be recorded as anything else. |

`UNKNOWN` is a deliberate class. The failure mode this gate guards against is
a chemistry drifting from "we have not checked" to "it is fine" without an
experiment in between.

## 4. Candidate register

**Every entry is UNKNOWN until an S2-E1 result exists.** Nothing below is a
recommendation.

| Candidate | Chemistry | Published as | Class | Evidence |
|---|---|---|---|---|
| Cu-PAN on porous substrate | Cu(II) 1-(2-pyridylazo)-2-naphthol → CuS + H-PAN | Carpenter et al. 2017, `research/papers.md` P4 | **UNKNOWN** | No retention experiment published. CuS insolubility is suggestive; in-situ HCl and reversible PAN binding argue the other way. |
| Cu-azo hydrogel | Cu(II)-azo complex in agarose | Wang et al. 2023 (via P1) | **UNKNOWN** | Primary source not obtained. |
| Printed Cu(II) azo label | Immobilised Cu(II) azo dye | Engel et al. 2021 (via P1) | **REVERSIBLE** | P1 states it explicitly. Disqualified unless the primary source contradicts the review. |
| QRsens H₂S layer | Not characterised in the paper | Escobedo et al. 2023, P2 | **REVERSIBLE** | 2-minute equilibrium readout. |
| Lead acetate | Pb(II) acetate → PbS | Classical; referenced throughout the literature | **UNKNOWN** | Classically treated as irreversible, but toxicity of the lead salt is a separate and probably disqualifying problem for a worn consumer-facing badge. |
| Liquid-crystal badge | — | `research/papers.md` P5, **not obtained** | **UNKNOWN** | The only mandated source describing a real cumulative H₂S badge. Acquiring it is the cheapest possible progress on this gate. |

**Action before any chemistry work:** obtain P5
(doi:10.1080/15459624.2014.916808). It is the one source in the mandated set
that is about an integrating H₂S badge, and it may already answer several of
the experiments below.

## 5. The experiments

Run in order. **E1 is a gate on the rest**: a reversible chemistry does not
proceed to E2.

### S2-E1 — retained response *(decisive)*

**Hypothesis:** the optical response persists after the analyte is removed.

| | |
|---|---|
| **Design** | Expose to a fixed `C × t`. Transfer to clean air. Read optically at t = 0, 15 min, 1 h, 4 h, 24 h, 72 h after removal. |
| **Conditions** | At minimum: 25 °C / 50 % RH, and the humid extreme of the intended envelope. Humidity is the most likely thing to reverse a reaction of this kind. |
| **Replicates** | ≥5 specimens per condition, ≥2 lots. |
| **Measured** | ΔE₀₀ from the t = 0 reading, and the drift in whichever scalar feature is the candidate response. |

**Pass criterion (proposed):** optical response decays by **less than 5 % of
the full-scale response over 24 h** in clean air, at every tested condition.

**Why 24 h:** it must comfortably exceed the read-by window — the worst case is
a badge closed at end of shift and photographed the next morning. If the
read-by window is later set shorter, this criterion can relax, but the window
must be set *first*.

**If it fails:** the chemistry is REVERSIBLE and is out. No optical or
statistical method recovers an exposure history from a sensor that has
forgotten it. Do not attempt to model the decay and back-extrapolate: that
requires knowing when the exposure occurred, which is the thing the badge was
supposed to tell us.

### S2-E2 — dose monotonicity

**Hypothesis:** the response is monotonic in cumulative dose over the intended
range.

| | |
|---|---|
| **Design** | ≥8 dose levels spanning and exceeding the intended range, at constant concentration. |
| **Replicates** | ≥5 per level, ≥2 lots. |
| **Measured** | Every candidate feature: L\*, a\*, b\*, ΔE₀₀ from blank, effective absorbance per channel, and any spatial feature. |

**Pass criterion:** for the chosen feature, the response is monotonic across
the range, with **no turning point and no plateau-then-resume**, and the
separation between adjacent dose levels exceeds the within-level spread.

**Why this is a real risk, not a formality.** Carpenter et al. Table 1, CIELAB
b\* against [H₂S] in ppb:

| ppb | 0 | 30 | 60 | 100 | 150 | 250 | 400 | 600 | 1000 | 1750 | 2500 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| b\* | −15.72 | −10.92 | −11.44 | −12.03 | −12.49 | −13.48 | −1.63 | −1.19 | −0.46 | 0.81 | 1.78 |

b\* rises, then falls monotonically 30 → 250 ppb, then jumps discontinuously,
then rises. The authors state plainly that "there is no linear correlation in
the range of 250–400 ppb" and defend quantification on **range separation**
rather than monotonicity. a\* shows no trend at all; L\* is flat and noisy.

If the chosen feature does this, a monotonic interpolator fitted through it
returns a confident wrong answer in the ambiguous region. The engine already
refuses to certify a non-monotonic feature
(`monotonicity` check, M0B scope) — but the right fix is chemistry or a second
sensing zone, not a cleverer regressor.

### S2-E3 — saturation and over-range behaviour

| | |
|---|---|
| **Design** | Doses at 1×, 2×, 5× and 10× the intended upper limit. |
| **Measured** | Where the response flattens; whether it **reverses** beyond saturation. |

**Why it matters more than it looks:** a response that rises, saturates and
then *reverses* makes a very high exposure read as a moderate one. That is a
false-reassurance failure on the worker with the worst exposure in the plant —
the highest-severity outcome this system can produce.

**Output:** the saturation point and the over-range behaviour, both into
`calibration_models.validated_range`.

### S2-E4 — equal-dose reciprocity *(the product's central claim)*

**Hypothesis:** endpoint state depends on `∫C dt` and not on the path taken.

| | |
|---|---|
| **Design** | Same nominal dose by several very different profiles. |
| **Profiles** | e.g. for 4 ppm·h: 0.5 ppm × 8 h · 1 ppm × 4 h · 2 ppm × 2 h · 4 ppm × 1 h · intermittent (1 ppm for 1 h, clean for 1 h, ×4) · back-loaded (clean 6 h, then 2 ppm × 2 h) |
| **Replicates** | ≥5 per profile, ≥2 lots, at ≥2 dose levels |
| **Measured** | The chosen feature, and its between-profile spread against its within-profile spread. |

**Pass criterion (proposed):** between-profile variation in the feature is
**no larger than the within-profile replicate spread**, i.e. profile shape is
not a detectable effect at the resolution the badge claims.

**The intermittent and back-loaded profiles are the important ones.** A
constant-concentration series with different durations mostly tests linearity.
Only an interrupted profile tests whether the chemistry can be partially
consumed, rest, and resume — and only a back-loaded one tests whether recent
exposure counts more than old exposure, which is what a slowly reversible
reaction looks like.

Note what SmART-Form did here, from `research/references/smart-form-analysis.md`:
their model asserts `CCR = f(C × T)` and their calibration pooled multiple
`(C, T)` pairs — but **every chamber test ran 72 h at constant concentration**.
That is a weak reciprocity test presented as a settled assumption. We should not
repeat it.

**If it fails:** a single endpoint photograph cannot uniquely recover cumulative
exposure. Directive §26 is explicit about the response: do not hide it with
machine learning. Redesign the transport or chemistry; constrain the validated
operating domain; use multiple sensing zones with different kinetics; or report
exposure bands rather than false precision.

### S2-E5 — shelf ageing and the blank

| | |
|---|---|
| **Design** | Unexposed specimens stored at the climate extremes, read at 0, 1, 3, 6, 12 months. |
| **Measured** | Drift in the unexposed response; whether the expiry indicator tracks it; whether the protected blank tracks it. |

**Why:** an aged badge that reads like an exposed one is a false positive on a
worker's record. The expiry patch is only useful if its change *correlates* with
the sensor's degradation, which is an experimental claim, not a design one.

**Pass criterion:** unexposed drift over the claimed shelf life stays below the
quantification limit, **and** the expiry indicator crosses its threshold before
the sensor's false-positive rate becomes material.

## 6. Software consequences

| Consequence | Where |
|---|---|
| `reversibility_class` becomes a required field | `formulations` |
| A formulation not classed IRREVERSIBLE/RETAINED cannot back a field-permitted model | calibration package gating |
| The certified monotonic interval becomes part of the feature definition | `calibration_models.feature_definition` |
| Saturation and over-range behaviour become explicit | `validated_range`; drives `SATURATED` / `ABOVE_RANGE` |
| Read-by window becomes enforceable | set by S2-E1, enforced on the badge lifecycle |
| Reciprocity outcome decides point estimate vs banded reporting | UI and result contract |

**No M0A code depends on the outcome.** M0A computes optical features and
asserts nothing about what they mean.

## 7. Decision record

| | |
|---|---|
| **Gate status** | OPEN |
| **Blocks** | any ppm·h claim; chemistry selection; M2 and M3 |
| **Does not block** | M0A, M0B, M1 |
| **Evidence to close** | S2-E1 passed, S2-E2 and S2-E4 passed, S2-E3 and S2-E5 quantified |
| **Cheapest next step** | obtain `research/papers.md` P5 |

If S2-E1 or S2-E4 fails, no image-processing or machine-learning model may be
represented as solving cumulative H₂S dosimetry.
