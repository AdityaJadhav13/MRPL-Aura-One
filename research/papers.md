# Scientific literature record

One record per paper, in the schedule the directive §3 requires. Where a field could not be
established from the source actually in hand, it says **not established** — it is never filled
by inference, and never filled from an abstract pretending to be a result.

**Provenance rule applied throughout:** a value appears here only if it was read in the full
text of the paper. Values taken from the 2024 review's *description* of another paper are
marked "(via review [P1])" and are second-hand until the primary source is obtained.

| ID | Short name | Full text in hand? |
|---|---|---|
| P1 | Kiwfo et al. 2024 — smartphone passive-sampler review | Yes — `research/atmosphere-15-00451-v2.pdf` |
| P2 | Escobedo et al. 2023 — QRsens | Yes — `research/QRsens- …pdf` |
| P3 | Zhang et al. 2019 — SmART-Form | Yes — `research/Smartphone App … (SmART-Form).pdf` |
| P4 | Carpenter et al. 2017 — Cu-PAN H₂S paper probe | Yes — `research/Quantitative, colorimetric paper probe …pdf` |
| P5 | Liquid-crystal H₂S passive badge (directive §3.5) | **No — not obtained. See P5.** |
| P6 | Kring et al. 1984 — passive colorimetric H₂S badge | **No — cover sheet only. See P6.** |

---

## P1 — Smartphone-Based Color Evaluation of Passive Samplers for Gases: A Review

| Field | Value |
|---|---|
| Authors | Kiwfo K., Grudpan K., Held A., Frenzel W. |
| Reference | *Atmosphere* **2024**, 15, 451 |
| DOI | [10.3390/atmos15040451](https://doi.org/10.3390/atmos15040451) |
| Target analyte | Review — NO₂, O₃, NH₃, H₂S, Hg vapour, formaldehyde, VOCs |
| Scope | 14 papers on smartphone evaluation of passive gas samplers |
| Relevance to DoseBand | **Highest.** This is the map, and it contains the single most important physical constraint on our product. |

### The type-1 / type-2 distinction — read this before designing the badge

The review's central critical finding, and one that appears nowhere in our existing
architecture documents:

> "a conceptual difference also exists between samplers that are suitable for gas concentration
> measurements and those providing information about the accumulated deposition flux … the
> former type requires a defined and sufficiently long diffusion path or adopts turbulence
> barriers in front of the absorbing layer to avoid wind-shortening effects. Within this review,
> we will name passive samplers of this configuration **type-1**; the others with uncontrolled
> (air velocity dependent) diffusion path lengths are accordingly termed **type-2**."

The physics (§1): uptake is governed by diffusion across a boundary layer whose thickness
changes with air velocity. Increasing airflow thins that layer and raises uptake **for the same
gas concentration**. If the diffusion path is not defined by the device's own geometry, what is
measured is the deposition flux (immission rate, mass per area per time) — which is *related* to
concentration but is not concentration, and cannot be converted to one without knowing the air
velocity history.

The review then observes, with evident surprise:

> "It is interesting (even surprising) that in none of the publications, this fact has been
> discussed, and in most of the publications, gas concentrations in, e.g., µg m⁻³ are given
> rather than the appropriate value for target gas deposition flux."

**11 of the 14 reviewed devices are type-2.** The authors state plainly that for type-2 devices
"the application of Fick's law of diffusion has sometimes been falsely used."

### What this means for DoseBand, concretely

A wrist-worn badge on a worker who moves, in a refinery where wind varies, with an open
colour-changing patch, is a **type-2 device**. Its endpoint colour would encode accumulated
deposition flux, not ∫C dt. Reporting ppm·h from it would be the error the review names.

To report ppm·h defensibly the badge must be type-1 **by construction**. The review states the
two accepted means (§1):

> "the open side of the badge-type passive samplers is generally either covered by a
> gas-permeable polymeric membrane (so that gas transport is no longer governed by diffusion
> rather than permeation) or porous plugs are inserted into the short diffusion path to act as a
> turbulence barrier"

and the consequence:

> "These measures, however, require evaluating the uptake rate of such samplers experimentally
> for proper quantification of target gas concentrations using calibration with standard gases
> and/or comparison with established reference methods."

This is a **hardware requirement that the software cannot compensate for**, and a calibration
requirement (face-velocity dependence of the uptake rate) that must be in the experimental plan.
It is escalated as finding **F-1** in `research/measurement-engine-audit.md`.

### Other findings recorded

- Tube-type samplers achieve a defined path via aspect ratio > ~5–8 (Palmes et al. 1976), after
  which wind shortening is insignificant and Fick's law applies without gas-phase calibration.
  Badge-type samplers have short paths, higher sampling rates, and greater wind sensitivity.
- Colour spaces used across the 14 papers: RGB most often; CIELAB, HSB and CMYK in some.
- Most papers export photos to a computer and use ImageJ. "Only in one case the inherent
  capability of the smartphone was employed."
- The review's own criticism of the field: "A deficiency of many papers can be seen in missing
  and difficult-to-understand description (or sometimes inadequate) calibration procedures."

### Leads extracted from P1 for follow-up (second-hand until obtained)

| Lead | Why it matters | Reference as printed in P1 |
|---|---|---|
| **Choi, Seo & Weon 2023** — o-dianisidine ozone passive sampler | **The closest architectural analogue found.** Badge-type, lapel-worn **personal** sampler; 0–200 ppb over variable durations **up to 8 h**; smartphone photo in a photobox; **"the effective absorbance of the blue scale … provide[d] the best fit"**; LOD 1.79 ppb, LOQ 5.27 ppb; calibrated against liquid extraction; field-tested in a printing store and a rubber factory, where room concentration and **personal** exposure differed significantly. | *J. Hazard. Mater.* **2023**, 460, 132510 |
| **Engel et al. 2021** — printed sensor labels, NH₃/HCHO/H₂S | QR-like code with integrated colour reference spots and a screen-printed H₂S layer (immobilised **copper(II) azo dye complex**) — architecturally very close to DoseBand. **But P1 records: "In the cases of detection of NH₃ and H₂S, the indicator reactions are reversible. Therefore, only the momentary response to varying gas concentrations is obtained (and not the commonly achieved time-weighted values of passive sampling devices)."** | *Sens. Actuators B Chem.* **2021**, 330, 129281 |
| **Wang et al. 2023** — Cu-azo complex hydrogel H₂S sensor | Cu-PAN in agarose hydrogel; response correlated with **log** of H₂S concentration, <1 ppm to ~50 ppm at 10 min; LOD 43.34 ppb (stated); RGB via the Color Assist app; **Euclidean distance** used as the colour metric. P1 notes photographing conditions are not reported. | *Sens. Actuators B Chem.* **2023**, 376, 132968 |

**The Engel finding is a chemistry gate for our project.** A reversible indicator cannot be a
cumulative dosimeter — it reports the concentration at the moment of reading and forgets the
exposure history. Several of the best-performing smartphone H₂S chemistries in this literature
are reversible. Escalated as finding **F-2**.

**Effective absorbance:** P1 refers to it but does not define it. The directive §20 is right to
warn against assuming a definition. Choi et al. must be obtained before any `EA` feature is
implemented; until then `EA = −log₁₀(I/I₀)` is an unsourced placeholder, not a paper-backed
formulation.

---

## P2 — QRsens: Dual-purpose quick response code with built-in colorimetric sensors

| Field | Value |
|---|---|
| Authors | Escobedo P., Ramos-Lorente C.E., Ejaz A., Erenas M.M., Martínez-Olmos A., Carvajal M.A., García-Núñez C., de Orbe-Payá I., Capitán-Vallvey L.F., Palma A.J. |
| Reference | *Sens. Actuators B Chem.* **376** (2023) 133001 |
| DOI | [10.1016/j.snb.2022.133001](https://doi.org/10.1016/j.snb.2022.133001) |
| Analytes | Temperature, RH, CO₂, NH₃, **H₂S** |
| Sampling mechanism | **Equilibrium, reversible.** "The exposure time for the tests was 2 min, time enough … to reach the equilibrium." Not a dosimeter. |
| Image acquisition | Smartphone via external camera app at fixed ISO 800 / EV 0.0 / AF / WB natural light; manual pinch-to-fit to an on-screen square |
| Lighting control | Both controlled illumination and correction across 3000 / 4000 / 5000 K |
| Reference patches | Two: one black, one white, printed at the centre of the code |
| Colour space | Corrected RGB → HSV |
| Optical feature | `H_norm = H/360` for H₂S (S for CO₂) |
| Localisation | Greyscale → Gaussian blur → global binary threshold → Circle Hough Transform; ROI radius reduced 20 % before sampling |
| Calibration model (H₂S) | One-phase exponential growth `y = A1·e^(x/A3) + A2` |
| H₂S parameters, controlled illumination | A1 = −0.37 ± 0.01; A2 = 1.1802 ± 0.0023; A3 = −0.273 ± 0.019; R² = 0.98934 |
| H₂S parameters, after light correction | A1 = −0.47 ± 0.03; A2 = 1.151 ± 0.007; A3 = −0.49 ± 0.04; R² = 0.98213 |
| Range (H₂S) | 0.01–0.6 ppm controlled; 0.13–0.7 ppm after correction |
| LOD (H₂S) | 0.01 ppm controlled; 0.13 ppm after correction. Method stated: `3·s_b` for exponential fits; tangent method for sigmoidal |
| LOQ | Not reported |
| Repeatability (H₂S) | CV 1.1 % at 0.5 ppm controlled; 2.8 % after correction |
| Environmental effects | Illumination SD reduced 75 % by correction (0.24 → 0.06) |
| Interferents | Cross-sensitivity < 3 % between the five sensors; exception NH₃ → RH sensor > 21 %, linearly correctable. **Mercaptans not tested.** |
| Limitations | Equilibrium not cumulative; two-point colour correction; manual alignment; hue discontinuity requires a hard-coded `+1` above 1 ppm |
| Relevance | Source of the §13 baseline correction. Architecture transfers; chemistry and calibration do not. |

Full teardown: `research/references/qrsens-analysis.md`.

---

## P3 — Smartphone App for Residential Testing of Formaldehyde (SmART-Form)

| Field | Value |
|---|---|
| Authors | Zhang S., Shapiro N., Gehrke G., Castner J., Liu Z., Guo B., Prasad R., Zhang J., Haines S.R., Kormos D., Frey P., Qin R., Dannemiller K.C. |
| Reference | *Building and Environment* **148** (2019) 567–578 |
| DOI | [10.1016/j.buildenv.2018.11.029](https://doi.org/10.1016/j.buildenv.2018.11.029) |
| Analyte | Formaldehyde |
| Sensor chemistry | Commercial Morphix Technologies colorimetric badge, modified for residential range |
| Sampling mechanism | **Passive, cumulative.** Model asserted as `CCR = f(E) = f(C × T)` |
| Image acquisition | Phone camera; fixed centre crop resized to 250 × 250; two 50 × 50 px ROIs |
| Devices | Huawei Mate 8 (Android 7.0), iPhone 6s (iOS 11.2), Casio Exilim F1 |
| Lighting control | None in the field. Warnings only. |
| Reference patches | **One** non-reacting calibration patch |
| Colour space | HSI; intensity `I = (R+G+B)/3` on gamma-encoded sRGB |
| Optical feature | Colour change ratio `CCR = I_reaction / I_calibration` |
| Calibration model | Linear: **y = −36301x + 36671**, y in ppb·hr, x = CCR |
| Fit quality | **R² = 0.8811, P < 0.0001** |
| Calibration conditions | 50 L chamber, 23 ± 0.5 °C, 72 h, 6 tests × 3 badges, verified by DNPH + HPLC |
| Range | 20–120 ppb at 72 h |
| LOD | 20 ppb at 72 h; method: **3 × SD of blank readings** (blanks = freshly opened, unexposed badges) |
| LOQ | Not separately reported |
| Repeatability | SD 10.9 ppb at 72 h with standard orientation to the light source |
| Environmental effects | **Unusable above ~75–80 % RH** (artificial blue tint). |
| Interferents | Acetaldehyde and a VOC mixture: no interference (P = 0.93). Acetone and ammonia untested. |
| **Field lighting effect** | **Same badges, natural vs indoor light: 80 vs 61 ppb (130 % higher) at one location; >120 vs 56 ppb (220 % higher) at another.** |
| Limitations (authors') | Untested lighting/orientation; linear reflectance model assumes "homogeneous and ambient light" only; cannot handle non-orthogonal views, concentrated sources or inhomogeneous shadows |
| Relevance | Closest product analogue. Source of the §14 ratio. Its field-lighting failure is the strongest available argument for multi-patch correction with held-out validation. |

Full teardown, including the shipped source: `research/references/smart-form-analysis.md`.

---

## P4 — Quantitative, colorimetric paper probe for hydrogen sulfide gas

| Field | Value |
|---|---|
| Authors | Carpenter T.S., Rosolina S.M., Xue Z.-L. (University of Tennessee, Knoxville) |
| Reference | *Sensors and Actuators B* **253** (2017) 846–851 |
| DOI | [10.1016/j.snb.2017.06.114](https://doi.org/10.1016/j.snb.2017.06.114) (directive §3.4; journal/volume/pages confirmed from the PDF) |
| Analyte | **H₂S gas** |
| Sensor chemistry | Copper(II) 1-(2-pyridylazo)-2-naphthol (**Cu-PAN**) on a moist, basic porous substrate. Purple → yellow. Two coloured products form. |
| Sampling mechanism | **Static exposure to a fixed 1.35 L gas volume**, short duration (e.g. 10 s at 5 ppm). Not passive diffusion, not a dosimeter. |
| Readout device | **Handheld colorimeter** (Variable Technologies Node+ with Chroma module), which transmits to a smartphone. **Not a phone camera.** Illuminant and geometry are controlled by the instrument. |
| Colour space | **CIELAB** |
| Optical feature | **b\*** — selected over a\* and L\* |
| Calibration model | Two separate linear correlations: low range (R² = 0.984) and high range (R² = 0.993) |
| Range | 30 ppb – 2500 ppb tested |
| LOD | **16 ppb**, stated as `3σ/n` |
| LOQ | **53 ppb**, stated as `10σ/n` |
| Naked-eye LOD | 30 ppb in 1.35 L |
| Repeatability | n = 3; b\* SDs 0.03–0.20 across the range |
| Humidity | **No significant effect on b\* at 600 ppb across 25, 50, 75 and 82 % RH** (Table S1) |
| Air vs N₂ | b\* = −1.14 in air vs −1.19 ± 0.09 in N₂ at 600 ppb — within error |

### Two findings that change how we design

**(a) The response is non-monotonic and discontinuous.** Table 1, b\* against [H₂S] in ppb:

| ppb | 0 | 30 | 60 | 100 | 150 | 250 | 400 | 600 | 1000 | 1750 | 2500 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| b\* | −15.72 | −10.92 | −11.44 | −12.03 | −12.49 | −13.48 | −1.63 | −1.19 | −0.46 | 0.81 | 1.78 |

b\* jumps **up** from 0 to 30 ppb, then falls monotonically through 250 ppb, then jumps to
−1.63 at 400 ppb and rises thereafter. The authors are explicit: "there is no linear correlation
in the range of 250–400 ppb". Their defence is separation, not monotonicity — "the b\* values do
not overlap with either the low or high concentration ranges."

a\* is worse (15.46 → 6.77 → 10.65 → 7.56, no trend). L\* is essentially flat and noisy.

So the directive's §28 monotonicity test is not a formality. In the nearest published H₂S
colorimetry, **a single scalar colour feature is non-monotonic over the analytical range**, and
quantification depends on a domain-separation argument that must itself be validated. Any
DoseBand feature we adopt has to be tested for this, and a model must never be allowed to
interpolate across a turning point.

**(b) Mercaptans produce a large false positive.** From §3.4:

> "The probe was exposed to 1.35 L of natural gas from the in-house supply with **0 ppb H₂S**.
> The probe changed to yellow and yielded a b\* value of 2.31, **correlating to 2.8 ppm H₂S**.
> This response is likely due to the reactions of Cu-PAN with mercaptans in the natural gas,
> typically in the 1–10 ppm range as an odorant."

A **2.8 ppm H₂S reading from zero H₂S**, caused by mercaptans. MRPL is a refinery. Mercaptans
are ubiquitous in refinery gas streams and are the standard odorant in fuel gas. If DoseBand
uses a Cu-PAN-family chemistry, this is not a theoretical interferent — it is an expected daily
exposure that would inflate a worker's recorded dose.

Escalated as finding **F-3**. Mercaptan cross-sensitivity must be a named, blocking item in the
interferent test matrix (§33), not one row among many.

| Field | Value |
|---|---|
| Limitations | Colorimeter not phone camera; fixed gas volume not passive uptake; non-monotonic response; severe mercaptan interference; reported sensitivity higher to aqueous sulfide than to gaseous H₂S, implying incomplete gas capture |
| Relevance | Best H₂S-specific colorimetric quantification in the mandated set. Establishes CIELAB b\* as the channel to beat, and supplies two hard design constraints. |

---

## P5 — Liquid Crystal-Based Passive Badge for Personal Monitoring of Exposure to Hydrogen Sulfide

| Field | Value |
|---|---|
| DOI (as given in directive §3.5) | 10.1080/15459624.2014.916808 |
| Expected journal | *Journal of Occupational and Environmental Hygiene* |
| Status | **NOT OBTAINED. This paper is not in `research/` and has not been read.** |

The directive marks this as "extremely important", and on its description it is the only
mandated source that is actually the same *kind of device* as DoseBand: a passive badge, for
personal monitoring, of cumulative H₂S exposure, reported in ppm·h, with a reaction-front
geometry read spatially.

**No field in this record has been filled, and none will be until the paper is in hand.** The
directive's §2 note that it covers "passive diffusion, cumulative exposure, ppm·h,
reaction-front geometry, spatial optical measurement, personal refinery monitoring,
reference-method comparison, environmental dependence" is a *description of what to look for*,
not a result, and must not be cited as one.

**This is the highest-value outstanding acquisition in the project**, because it is the only
mandated source that can tell us whether spatial reaction-front measurement (§23) is the right
architecture, and what environmental dependence a real H₂S dosimeter badge exhibits. Escalated
as finding **F-4**.

---

## P6 — Laboratory Validation and Field Verification of a New Passive Colorimetric Air Monitoring Badge for Sampling Hydrogen Sulfide in Air

| Field | Value |
|---|---|
| Authors | Kring E.V., Damrell D.J., Henry T.J., DeMoor H.M., Basilio A.N., Simon C.E. |
| Reference | *American Industrial Hygiene Association Journal* **45**(1) (1984) 1–9 |
| DOI | [10.1080/15298668491399271](https://doi.org/10.1080/15298668491399271) |
| Status | **Body text NOT obtained.** The file `research/Laboratory Validation and Field Verification …pdf` contains **only the Taylor & Francis cover sheet** — 1 220 bytes of text, no article content. |

Note this is **not** the paper the directive asked for at §3.5; the DOIs differ. It appears to
have been acquired in its place.

On its title it is highly relevant — a laboratory-validated *and field-verified* passive
colorimetric H₂S badge, from the era when the DuPont/Pro-Tek-style badges were qualified against
reference methods. That is precisely the validation template §48 describes. But **nothing can be
recorded from a cover sheet**, and nothing is.

Acquisition of the full text is recommended alongside P5.

---

## Coverage assessment against directive §3

| Directive requirement | Status |
|---|---|
| §3.1 — 10.3390/atmos15040451 (literature map) | ✅ read in full (P1) |
| §3.2 — 10.1016/j.snb.2022.133001 (QRsens) | ✅ read in full (P2) |
| §3.3 — 10.1016/j.buildenv.2018.11.029 (SmART-Form) | ✅ read in full (P3) |
| §3.4 — 10.1016/j.snb.2017.06.114 (H₂S paper probe) | ✅ read in full (P4) |
| §3.5 — 10.1080/15459624.2014.916808 (liquid-crystal badge) | ❌ **not obtained** (P5) |
| "Follow the references in the 2024 review for ozone, formaldehyde, NO₂, NH₃, CO, VOCs, multi-gas arrays" | ◐ three leads extracted and recorded (Choi, Engel, Wang); the remaining reviewed papers are catalogued in P1's Table 1 but not yet individually retrieved |

Four of five mandated papers are read in full. The gap is P5, and it is the one that matters
most for the dosimetry question specifically.
