# GATE S3 — Selectivity and interference validity

**Status:** OPEN — blocking any claim of H₂S specificity
**Owner:** chemistry + laboratory, with MRPL process input
**Decides:** whether a colour change on a DoseBand badge means H₂S
**Raised by:** finding F-3, `research/measurement-engine-audit.md`

---

## 1. The question

The badge does not measure H₂S. It measures a colour change that we intend to
be caused by H₂S. Whether those are the same thing is an experimental question,
and the one piece of hard evidence we have says they are not.

> **Do not claim H₂S specificity until it has been tested.**

A false positive here is not a nuisance. It lands on a worker's cumulative
exposure record, and a record inflated by a routine, harmless co-exposure is
indistinguishable from a real overexposure at review time.

## 2. Documented evidence

Everything in this section was read in the full text of the cited paper.
Nothing here is inference.

### D1 — Mercaptans produce a large false positive on Cu-PAN **[severity: critical]**

Carpenter et al. 2017 (`research/papers.md` P4), §3.4, verbatim:

> "The probe was exposed to 1.35 L of natural gas from the in-house supply with
> **0 ppb H₂S**. The probe changed to yellow and yielded a b\* value of 2.31,
> **correlating to 2.8 ppm H₂S**. This response is likely due to the reactions
> of Cu-PAN with mercaptans in the natural gas, typically in the 1–10 ppm range
> as an odorant."

A 2.8 ppm H₂S reading, from zero H₂S. On the chemistry family that is our
leading candidate.

**Why this is the headline risk for MRPL specifically:** mercaptans are not an
exotic laboratory interferent in a refinery. They are present in LPG and fuel
gas streams, they are the standard odorant added to fuel gas, and mercaptan
removal is itself a refinery process unit. A worker near a fuel gas line would
accumulate a mercaptan-driven "exposure" all shift.

### D2 — Sulfide and mercaptan sensitivity are of the same order

Same paper, §3.3. Response slopes of b\* for equal gas-phase-equivalent
concentrations:

| Species | R² | Slope |
|---|---|---|
| S²⁻(aq) | 0.993 | −0.0225 |
| H₂S(g) | 0.984 | −0.0113 |
| MPTMS (a mercaptan, aqueous) | 0.954 | −0.011 |

The mercaptan slope is **essentially equal to the H₂S slope**. This is not a
small cross-sensitivity to be corrected; on this chemistry the two analytes are
close to indistinguishable by magnitude.

The paper attributes the somewhat reduced mercaptan reactivity to "steric
hindrance of the R groups" — which implies the interference varies with *which*
mercaptan, and small mercaptans will interfere more.

### D3 — Humidity does not affect Cu-PAN **[favourable]**

Same paper, §3.4: no significant effect on b\* for a probe exposed to 600 ppb
H₂S at **25, 50, 75 or 82 % RH** (Table S1).

Worth recording as a favourable result, and worth contrasting with SmART-Form,
whose formaldehyde badge is unusable above ~75–80 % RH because of an artificial
blue tint. Humidity robustness is chemistry-specific and cannot be assumed
either way.

### D4 — Air versus nitrogen makes no difference to Cu-PAN **[favourable]**

Same paper, §3.4: b\* = −1.14 in air versus −1.19 ± 0.09 in N₂ at 600 ppb —
within error. Bulk oxygen is not an interferent for this chemistry.

### D5 — QRsens cross-sensitivities

Escobedo et al. 2023 (`research/papers.md` P2), §3.3: interference between its
five sensors "is below 3 %", with one exception — NH₃ on the humidity sensor,
>21 %, for which a linear correction is given.

**Scope limit:** this is cross-sensitivity among *that system's own five
sensors* (temperature, RH, CO₂, NH₃, H₂S). It says nothing about refinery
hydrocarbons, and **mercaptans were not tested**.

### D6 — SmART-Form's interference result does not transfer

Acetaldehyde and a VOC mixture did not interfere (P = 0.93). This is a
formaldehyde badge with completely different chemistry, and the result is
recorded only so it is not mistaken for evidence about ours.

### What the documented evidence adds up to

| | |
|---|---|
| Tested and interfering | Mercaptans (severely), on Cu-PAN |
| Tested and not interfering | Humidity 25–82 %, bulk air/O₂, on Cu-PAN |
| Tested on a different chemistry | Acetaldehyde, generic VOCs |
| **Everything else** | **untested** |

## 3. Hypothesised interferents — refinery interference matrix

**Read this section as a test plan, not as findings.**

Nothing below has been tested on any DoseBand chemistry. The species are
selected from general refinery process knowledge and from the reaction
chemistry of the candidate families (metal–azo complexes reacting with
nucleophilic sulfur). Presence, concentration and co-location at MRPL are
**assumptions that must be confirmed with MRPL process safety** — they are not
claims about their site.

Priority: **P1** must be tested before any field deployment; **P2** before any
accuracy claim; **P3** as resources allow.

### Sulfur species — the ones that share our reaction chemistry

| Species | Why suspected | Refinery source (assumed) | Priority |
|---|---|---|---|
| Methyl / ethyl mercaptan | **D1, D2 — documented severe interference** | Fuel gas odorant, LPG, mercaptan treating | **P1** |
| Higher mercaptans (propyl, butyl, thiophenol) | Same mechanism; D2 suggests steric bulk reduces but does not remove it | Naphtha, kerosene streams | **P1** |
| Carbonyl sulfide (COS) | Hydrolyses to H₂S; may react directly | FCC gas, Claus tail gas | **P1** |
| Carbon disulfide (CS₂) | Nucleophilic sulfur | FCC, some crudes | P2 |
| Dimethyl sulfide / disulfide | Nucleophilic sulfur | Sour streams, sulfur recovery | P2 |
| Sulfur dioxide (SO₂) | Acid gas; may bleach or shift a dye | SRU tail gas, flares, fired heaters | **P1** |
| Elemental sulfur vapour / dust | Physical deposition on the sensing window | Sulfur recovery, storage, loading | P2 |
| Thiophenes | Aromatic sulfur, generally unreactive — included to establish a negative | Crude, FCC feed | P3 |

### Acids, bases and process chemicals

| Species | Why suspected | Source (assumed) | Priority |
|---|---|---|---|
| Ammonia (NH₃) | pH shift; many colorimetric dyes are pH-sensitive | Sour water stripper, hydrotreater effluent | **P1** |
| Amines (MDEA, DEA, MEA) | Basic vapours; pH shift | Amine treating and regeneration | **P1** |
| Sulfuric acid mist | Strong acid; D1's own mechanism involves in-situ HCl dissolving the coloured product | Alkylation, SRU | P2 |
| Chlorides / HCl | Directly implicated — Carpenter reports CuS dissolved by HCl from the reaction | Crude desalting, overhead corrosion | **P1** |
| Caustic (NaOH) aerosol | pH shift | Caustic treating | P2 |

### Hydrocarbons and combustion products

| Species | Why suspected | Source (assumed) | Priority |
|---|---|---|---|
| Aromatics (benzene, toluene, xylene) | Solvent effects on an immobilised dye; substrate swelling | Reformer, FCC, tankage | P2 |
| Aliphatics (C1–C6) | Bulk exposure; establishing a negative matters | Fuel gas, LPG | P2 |
| Carbon monoxide | Reducing atmosphere | Fired heaters, FCC regenerator | P3 |
| Carbon dioxide | Weak acid, may shift pH in a hydrated layer | Ubiquitous | P2 |
| NOₓ | Oxidising; may bleach a dye | Fired heaters, flares | P2 |

### Environmental and physical

| Agent | Why suspected | Priority |
|---|---|---|
| Humidity beyond 82 % | D3 tested only to 82 %; coastal Karnataka exceeds it | **P1** |
| Salt aerosol | Coastal site; ionic deposition on the sensing layer | **P1** |
| Temperature extremes | Reaction kinetics and substrate behaviour; overlaps GATE S1-E4 | **P1** |
| Direct sunlight / UV | Photobleaching of an azo dye is a well-known failure mode | **P1** |
| Particulate / dust / soot | Physical obscuration; the engine sees it as a colour change | P2 |
| Oil mist, hand contamination, sunscreen, solvents | Deposition on the sensing window during a shift | P2 |
| Mechanical abrasion | Wristband rubbing against PPE | P2 |

Several of the physical agents are partly addressable in software: the
within-ROI heterogeneity statistic already computed by `sampleRoi`
(`maximumChannelIqr`) is the intended basis for a contamination check, because
a droplet or a fibre is blotchy where a real chemical response is uniform.
**The threshold for that check does not exist yet** and needs coupons.

## 4. The experiments

### S3-E1 — single-interferent screen *(decisive for P1 species)*

| | |
|---|---|
| **Design** | Expose specimens to each P1 species **alone, with zero H₂S**, at a realistic workplace concentration and a shift-length duration. |
| **Replicates** | ≥5 per species, ≥2 lots |
| **Measured** | Apparent dose the pipeline would report, if the badge were read as if the response were H₂S. |

**Reporting rule — this is the point of the experiment:** every result is
expressed as **apparent ppm·h from zero H₂S**. Not "a small Δb\*". The number
that matters is the one that would land on a worker's record.

**Pass criterion (proposed):** apparent dose from any single P1 interferent at
its realistic concentration stays **below the limit of quantification**.

**If it fails on mercaptans** — which D1 and D2 say it will, for Cu-PAN — the
options, in order:

1. **Change the chemistry** to one that discriminates nucleophilic sulfur
   species. Preferred, and it is a chemistry problem.
2. **Multi-zone discrimination.** Directive §33's `sensor A / sensor B / blank`
   architecture stops being optional. Two zones with *different* relative
   sensitivities to H₂S and mercaptans give a response *ratio* that can
   discriminate, where either zone alone cannot. This has real cost: badge
   area, a second chemistry, a second calibration, and its own validation.
3. **Physical pre-filter** over the aperture that removes mercaptans and passes
   H₂S. This interacts directly with GATE S1 — any added layer changes the
   diffusion path and the sampling rate, so S1 must be re-run.
4. **Declare the limitation.** Report that DoseBand measures "reactive sulfur
   species" rather than H₂S specifically, and let the safety officer interpret
   it. Honest, and substantially less useful.

**What must not happen:** a correction for mercaptans fitted from data, or an
ML classifier trained to "tell them apart" from a single patch colour. If one
patch gives one number, two analytes that both move it are not separable. That
is information theory, not a modelling problem.

### S3-E2 — interferent in the presence of H₂S

Single-species screening finds additive interference. It misses the more
dangerous kind.

| | |
|---|---|
| **Design** | Fixed, known H₂S dose, with and without each P1 interferent co-present. |
| **Measured** | Whether the interferent **suppresses** the H₂S response as well as adding to it. |

**Why this matters more than E1.** A species that consumes the reagent without
producing the coloured product makes a real H₂S exposure read **low**. That is
a false negative on a genuinely exposed worker, and it is the worst outcome in
the whole matrix. E1 cannot detect it, because E1 runs at zero H₂S.

**Pass criterion:** recovery of the known H₂S dose stays within the accuracy
target with the interferent present.

### S3-E3 — realistic mixture

A synthetic refinery atmosphere containing the plausible co-exposures at once.
Interference is not guaranteed to be additive, and this is the closest
laboratory approximation to the deployment condition.

### S3-E4 — photostability

Direct sun and UV exposure at zero H₂S, over shift-length durations. Azo dye
photobleaching would drive the response in the *opposite* direction to
exposure, which is a false negative that a sunny outdoor shift produces for
free.

### S3-E5 — surface contamination discrimination

Deliberately contaminate specimens — oil droplet, fingerprint, dust, sunscreen,
fibre — and establish whether the within-ROI heterogeneity statistic separates
them from a uniform chemical response.

**Output:** the threshold for `CONTAMINATION_SUSPECTED`, which is currently a
state with no number behind it.

### S3-E6 — blank and multi-zone discrimination power

If a protected blank and/or a second sensing zone exist, quantify how much
discrimination they actually provide against the P1 species. This is what
decides whether the multi-zone architecture earns its cost.

## 5. Software consequences

| Consequence | Where |
|---|---|
| Interference results recorded per formulation, per species, with apparent dose | new `interference_results` table, referencing `formulations` |
| `CONTAMINATION_SUSPECTED` gets a real threshold | from S3-E5 |
| A multi-zone badge changes the feature vector and the geometry | `feature_definition`, `badge_geometries` |
| Any residual known interference must be disclosed in the result, not buried | result presentation |
| A pre-filter invalidates the S1 sampling rate | GATE S1 must re-run |

**No M0A code depends on the outcome**, except that the contamination threshold
remains unset — which is why no contamination gate ships in M0A.

## 6. Claim discipline

Until S3-E1 and S3-E2 have passed for the selected chemistry, the following may
not be written or said, anywhere, including in a demonstration:

- "H₂S specific"
- "selective for hydrogen sulfide"
- "no interference"
- "measures hydrogen sulfide exposure"

What may be said:

- "responds to H₂S; selectivity against refinery co-exposures is under test"
- "measures reactive sulfur species" — if that turns out to be what it does

## 7. Decision record

| | |
|---|---|
| **Gate status** | OPEN |
| **Blocks** | any specificity claim; field deployment; M3 |
| **Does not block** | M0A, M0B, M1 |
| **Evidence to close** | S3-E1 and S3-E2 passed for all P1 species; S3-E3…E6 quantified |
| **Prerequisite** | MRPL confirmation of which species are actually present, at what concentrations, in the areas workers occupy. This is open question U-series work and can start immediately — it costs nothing but a conversation. |

Unlike S1 and S2, S3 is not a gate on whether the product is *possible*. It is
a gate on what the product may be said to measure.
