# Contradictions, unknowns and assumptions

Anything here that is resolved must be moved into a decision or a requirement. Nothing here
may be silently assumed away in code.

## 1. Contradictions found

### C1 — Two competing project roots
`app/` (a stock Flutter counter app) sits at the repository root, while `H2S-DoseBand/`
contains an empty `app/`, `docs/`, `assets/` skeleton. Both cannot be the project.
**Proposal:** repository root is the project; fold `H2S-DoseBand/`'s intended structure into
root `docs/` and `assets/`, then remove the empty directory. Nothing is lost — it contains
one 63-byte README.
**Needs a decision.**

### C2 — The directive asks for production-grade delivery; the science does not exist yet
Directive §33 targets a Play Store production rollout. The dossier is unambiguous that no
strip has been fabricated and no gas experiment run. A production release that reports ppm·h
would be a false-reassurance failure of the highest severity (directive §44).
**Resolution adopted:** build the complete instrument, ship it to internal/closed testing
only, and gate the ability to produce a non-simulated numeric result behind the existence of
a signed, validated calibration model. With no such model installed, the app is fully
functional and every result is `UNSUPPORTED_CALIBRATION` or `SIMULATED`. This is not a
degraded mode; it is the correct behaviour.

### C3 — "AI role" expectations vs. what the physics allows
The brief's framing and typical hackathon expectation favour visible ML. The dossier states
plainly that an ambiguous chemical response cannot be disambiguated by a neural network, and
that an LLM is unnecessary for dose inference.
**Resolution adopted:** deterministic CV and monotonic calibration first. ML is admitted only
where it has a defensible job (ROI localisation, glare/contamination rejection) and only
after it beats the deterministic baseline on held-out specimens. Recorded in ADR-0003.

### C4 — Directive §1 lists "identify a worker"; directive §20 says minimise PII
Identifying a worker and minimising personal data pull in opposite directions.
**Resolution adopted:** split identity from exposure. Exposure records reference an opaque
`worker_token`. The mapping token → person lives in a separate table with its own stricter
RLS, readable only by roles that genuinely need it. Most screens and all exports operate on
tokens.

### C5 — Wrist placement vs. breathing-zone representativeness
The brief mandates a wristband. The dossier is explicit that the wrist measures its own
microenvironment, which may differ from the breathing zone, and that no universal correction
exists.
**Software consequence:** `wearing_location` is a recorded field, results carry a
representativeness caveat, and the app must never imply the reading is a breathing-zone
exposure. Not a software-solvable problem; a software-disclosable one.

### C6 — Toolchain drift
Installed Flutter 3.41.2 / Dart 3.11.0 (≈7 months old). Current stable 3.47.5 / Dart 3.13.4.
Latest `riverpod` 3.4.3, `go_router` 18.0.1 and `camera` 0.12.1 all require Dart ≥3.12; on the
installed SDK they resolve down to 3.3.2, 17.5.0 and 0.12.0+2.
**Proposal:** upgrade Flutter before Phase 1. It is the cheapest possible moment to do it.
**Needs a decision.**

## 2. Unknowns that block numbers, not architecture

Each has a designed home in the schema so that filling it in later is data entry, not a
rewrite.

| Unknown | Blocks | Designed home |
|---|---|---|
| Calibration coefficients / LUT | Any dose value | `calibration_models.parameters` |
| Limit of quantification | `BELOW_QUANTIFICATION_LIMIT` boundary | `calibration_models.validated_range` |
| Saturation point | `SATURATED` / `ABOVE_RANGE` boundary | same |
| Uncertainty budget | Every interval reported | `calibration_models.uncertainty_model` |
| Colour-correction residual threshold | `REFERENCE_PATCH_FAILURE` trigger | `reference_profiles.max_delta_e` |
| Blank–sensor disagreement threshold | `SENSOR_BLANK_DISAGREEMENT` | `calibration_models.parameters` |
| Expiry patch → sensor-failure correlation | `BADGE_EXPIRED` confidence | `badge_batches`, ageing study |
| Validated climate envelope | `ENVIRONMENT_OUTSIDE_VALIDATED_RANGE` | `calibration_models.environmental_domain` |
| Read-by window after closure | Retention enforcement | `badge_geometries` / batch policy |
| Final badge geometry and ROI coordinates | ROI sampling | `badge_geometries.roi_definition` (versioned data) |
| Measured print values of reference patches | Colour correction | `reference_profiles.patch_values` |

## 3. Unknowns that need a human, not a lab

| # | Question | Ask whom |
|---|---|---|
| U1 | Is the target screening, hygiene assessment, or compliance measurement? | MRPL, via authorised channel |
| U2 | Required accuracy, exposure range, minimum useful sensitivity | MRPL industrial hygienist |
| U3 | Reporting fields, data access, retention rules, hosting constraints | MRPL IT / data owner |
| U4 | Can a phone be used in the work area, or is a scan station required? | MRPL safety |
| U5 | Does a controlled-light scan dock exist in the plan, or is it handheld only? | Team |
| U6 | Android-only, or iOS too? | Team — affects camera and CV validation cost |
| U7 | Minimum Android version and the actual low-end device to validate against | Team |
| U8 | Are contractor/temporary workers in scope? | MRPL — affects identity model |

U6 and U7 are the only ones that affect Phase 1. The rest can be answered while building.

## 4. Assumptions adopted in the absence of answers

Stated so they can be challenged, and each is cheap to reverse.

- **A1** Android is the primary target; the codebase stays iOS-capable but iOS is not validated.
- **A2** minSdk 24. Revisit when U7 is answered.
- **A3** One badge per worker per shift. Multi-badge (wrist + collar comparison) is a
  research configuration, modelled but not surfaced in the worker UI.
- **A4** A scan happens after closure, at a station, not mid-shift. Mid-shift reads are
  permitted by the data model (they supersede) but not encouraged by the UI.
- **A5** Organisation hierarchy is Organisation → Site → Department → Worker, per directive §17.
- **A6** English-only for Phase 1–9. Localisation structure in place from the start; Kannada
  and Hindi are realistic Phase 12 additions for a Mangaluru refinery.
