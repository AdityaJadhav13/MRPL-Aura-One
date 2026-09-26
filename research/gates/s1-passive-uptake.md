# GATE S1 — Passive uptake validity

**Status:** OPEN — blocking the ppm·h claim
**Owner:** badge mechanical design + laboratory
**Decides:** whether DoseBand's physical architecture can report cumulative exposure in ppm·h at all
**Raised by:** finding F-1, `research/measurement-engine-audit.md`

---

## 1. The question

DoseBand's output is defined as

    D = ∫ C(t) dt        [ppm·h]

A passive badge does not measure `C`. It accumulates analyte. The question this
gate answers is whether the quantity it accumulates is proportional to `∫C dt`
with a **stable, known constant of proportionality** — or whether that constant
moves with how fast air happens to be passing the worker's wrist.

If it moves, the badge is measuring something else, and no image-processing or
machine-learning work anywhere downstream can recover the difference.

## 2. The physics

For a diffusive sampler operating as a perfect sink — analyte concentration at
the absorbing surface held at zero by the chemistry — steady-state transport
follows Fick's first law, and the accumulated mass is

    m = D_g · (A / L_eff) · ∫C dt

where

| Symbol | |
|---|---|
| `m` | mass of analyte collected |
| `D_g` | diffusion coefficient of H₂S in air (temperature- and pressure-dependent) |
| `A` | cross-sectional area of the diffusion path |
| `L_eff` | **effective** diffusion path length |

The grouping `SR = D_g · A / L_eff` is the **sampling rate**, with dimensions of
volume per time. Inverting:

    ∫C dt = m / SR

**This is the whole product in one line.** A cumulative dose in ppm·h is
obtainable if and only if `SR` is known and stable. The optical pipeline
measures a proxy for `m`; `SR` is what converts it into an exposure.

*(The relation above is the standard passive-sampling form. Kiwfo et al. 2024
(`research/papers.md` P1) states that gas-phase concentration "can be derived
from Fick's first law of diffusion" for samplers with a defined path, and that
"gas-phase calibration of the samplers for analyte quantification is not
required" in that case. The symbolic equation is textbook, not a verbatim quote
from a paper read in full.)*

## 3. Why `L_eff` is the problem

`L_eff` is not the geometry of the device alone:

    L_eff = L_device + L_boundary

`L_boundary` is the stagnant air layer clinging to the sampler face. Its
thickness falls as air velocity over the face rises. Kiwfo et al. §1:

> "The diffusion layer thickness changes with variable air flow velocities
> along the sampler, i.e., increasing air flow enhances the transfer of the
> gaseous compound to the absorber and leads to a higher uptake of the target
> compound **for a given target gas concentration at a fixed sampling time**."

So for a device where `L_boundary` is a significant fraction of `L_eff`, uptake
depends on wind as well as on concentration. What is accumulated is then the
**deposition flux** (the review's term: immission rate, mass per area per
time), which is related to concentration but is not concentration and cannot be
converted to it without the air-velocity history.

The review's classification:

| | Definition | Reports |
|---|---|---|
| **Type-1** | Defined, sufficiently long diffusion path, or a turbulence barrier in front of the absorbing layer | Concentration / cumulative exposure |
| **Type-2** | Uncontrolled, air-velocity-dependent path length | Accumulated deposition flux |

Of the 14 smartphone passive-sampler publications reviewed, **3 are type-1 and
11 are type-2**. The review notes with evident surprise that none of the 14
discusses the distinction, and that for type-2 devices "the application of
Fick's law of diffusion has sometimes been falsely used."

## 4. Where DoseBand currently sits

**A wrist-worn badge with an open colour-changing patch is a type-2 device.**

Worse than the ambient-air case: the sampler is strapped to a limb that swings.
The relative air velocity at the badge face is not merely the site wind, it is
the site wind plus the worker's own arm motion, and it varies over the shift in
a way nobody records.

Under the current architecture DoseBand would accumulate `∫(flux) dt`, and
reporting that number as ppm·h would be exactly the error the review names.

## 5. What would make DoseBand type-1

The review gives the two accepted remedies (§1):

> "the open side of the badge-type passive samplers is generally either covered
> by a gas-permeable polymeric membrane (so that gas transport is no longer
> governed by diffusion rather than permeation) or porous plugs are inserted
> into the short diffusion path to act as a turbulence barrier"

### Option A — defined static air gap (Palmes geometry)

Make `L_device` long enough that `L_boundary` is negligible by comparison. The
review records the established criterion for tube-type samplers: an aspect
ratio (length to internal diameter) **above about 5–8**, after which "wind
shortening effects caused by eddies entering the tubes become insignificant."

- **Cost:** a badge deep enough to satisfy this is no longer a thin wristband.
  For a 6 mm aperture the path is ~30–48 mm. That is a fundamental conflict
  with the product form factor and needs to be confronted, not designed around.
- `SR` is then calculable from geometry and `D_g`, and needs experimental
  confirmation rather than experimental determination.

### Option B — gas-permeable membrane

Cover the aperture with a permeable polymer. Transport becomes **permeation
through a solid**, whose rate is set by the membrane's permeability and
thickness, not by the external boundary layer.

- **Cost:** `SR` is no longer calculable from geometry. It must be determined
  experimentally, and it depends on the membrane lot, on temperature, and
  possibly on humidity.
- **This is the likely answer for a wrist form factor**, and it converts S1
  from a geometry problem into a characterisation problem.

### Option C — porous turbulence barrier

A porous plug or diffusion screen in a short path. Intermediate between A and B.

### In every case

> "These measures, however, require evaluating the uptake rate of such samplers
> experimentally for proper quantification of target gas concentrations using
> calibration with standard gases and/or comparison with established reference
> methods."

So `SR` becomes a **measured, versioned, lot-specific property of the badge**,
with its own uncertainty, and it belongs in the calibration package alongside
the optical coefficients.

## 6. The falsification experiment

This is the experiment that can tell us the architecture does not work. It is
specified so that it can fail.

### S1-E1 — face velocity sensitivity *(the decisive one)*

**Hypothesis under test:** the sampling rate `SR` is independent of face
velocity across the range a wrist experiences.

| | |
|---|---|
| **Design** | Identical specimens exposed to the **same** nominal `C × t` at controlled face velocities. |
| **Velocity levels** | Still air (<0.05 m/s), 0.25, 0.5, 1.0, 2.0, 4.0 m/s at the badge face. The upper end must cover arm-swing speed; if walking arm motion exceeds it, extend the range rather than the conclusion. |
| **Replicates** | ≥5 specimens per level, from ≥2 manufacturing lots. |
| **Reference** | Chamber concentration measured continuously by a qualified instrument, independent of the badge. |
| **Measured** | `SR` at each velocity, computed as `m / ∫C dt`. |

**Pass criterion (proposed, to be agreed before the experiment runs):** `SR`
varies by **no more than ±10 %** across the full velocity range.

**Why ±10 %:** it should be a minority contributor to the total uncertainty
budget. It is proposed, not derived, and whoever owns the accuracy target must
either accept it or replace it — *before* data exists, not after.

**If it fails:**

1. Go to Option A or B and repeat. This is a **hardware fix, not a software
   one.**
2. If no architecture passes, DoseBand does not report ppm·h. The honest
   fallbacks, in order of preference:
   - report **exposure bands** with the velocity dependence folded into the band
     width;
   - report a **deposition-flux** quantity in its correct units, which is a real
     measurement but a different product;
   - state a validated operating domain that excludes high air movement, and
     refuse outside it — which for a refinery worker is likely to mean refusing
     most of the time.

**What must not happen:** fitting a correction for air velocity from data we do
not have. There is no wrist anemometer, and directive §32 already forbids the
equivalent move for temperature and humidity.

### S1-E2 — orientation sensitivity

Same dose, badge face at 0°, 45° and 90° to the flow. Establishes whether
`SR` depends on how the wristband happens to be rotated on the arm — which the
worker controls and nobody records.

**Pass criterion:** within the same ±10 % band as S1-E1.

### S1-E3 — sampling rate determination and its uncertainty

Once an architecture passes E1 and E2: determine `SR` and its confidence
interval across ≥3 manufacturing lots, at the validated temperature extremes.
Output is a value with an uncertainty, for the calibration package — not a
single number.

### S1-E4 — temperature dependence of `SR`

`D_g` varies with temperature (approximately as `T^1.75` for gas-phase
diffusion), and a membrane's permeability varies more steeply still. Determine
`SR` at the low, middle and high ends of the intended climate envelope.

For a refinery in coastal Karnataka the high end is not a formality.

### S1-E5 — reverse diffusion / back-diffusion check

Expose, then hold in clean air for a shift-equivalent period, then read. Tests
whether the perfect-sink assumption holds or whether collected analyte
re-emerges. Overlaps with GATE S2 and should be run jointly.

## 7. Software consequences

Regardless of outcome, these follow:

| Consequence | Where |
|---|---|
| `SR` and its uncertainty become calibration-package fields | `calibration_models.parameters`, plus a new `uptake_rate` block |
| A validated face-velocity domain becomes a field | `calibration_models.environmental_domain` |
| Dose is `m / SR`, so `SR` uncertainty propagates into every reported interval | uncertainty model |
| Badge orientation on the wrist may need recording | `badge_assignments.wearing_location` already exists; may need an orientation field |
| Until S1 closes, no schema or UI may present ppm·h from a field scan | already true by construction — no field-permitted calibration model exists |

**No M0A code depends on the outcome.** Geometry, colour science and reference
validation are unaffected by how the analyte arrived. That is why M0A could
proceed while this gate is open.

## 8. Decision record

| | |
|---|---|
| **Gate status** | OPEN |
| **Blocks** | any ppm·h claim; badge cartridge design freeze; M2 and M3 |
| **Does not block** | M0A, M0B, M1 |
| **Evidence required to close** | S1-E1 and S1-E2 passed on the selected architecture, with S1-E3 and S1-E4 quantified |
| **Who can close it** | not the software team |

If S1 fails, no image-processing or machine-learning model may be represented
as solving cumulative H₂S dosimetry. It would be solving a different problem
and labelling it with this one's units.
