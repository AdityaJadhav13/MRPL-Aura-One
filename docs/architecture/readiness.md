# What can be built now, and what must wait for the laboratory

The dividing line is not "software vs hardware". It is: **does this artefact assert anything
about the chemistry?** If no, build it now. If yes, build the machinery now and leave the
values empty.

## Buildable now — the complete instrument, minus its constants

| Area | Build now | Why it is safe |
|---|---|---|
| Design system, navigation, all 25 screens | Yes, fully | Asserts nothing about chemistry |
| Worker workflow end to end | Yes, fully | Lifecycle logic is independent of dose values |
| QR format, badge lifecycle, assignment | Yes | Identity and state, not measurement |
| Camera capture and live guidance | Yes, fully | Guidance thresholds are optical, validated against printed targets |
| Fiducial detection, homography, rectification | Yes, fully | Pure geometry. Testable against printed targets today. |
| Colour correction and held-out validation | Yes, fully | This is dossier V0 — a real, valid experiment needing no gas |
| Feature extraction | Yes — the code | Which statistics to compute is a design choice; what they *mean* is not |
| Calibration model machinery | Yes — loading, versioning, checksum, interpolation, domain checks | The container, not the contents |
| Validity engine and result state machine | Yes, fully | The states exist independently of the thresholds |
| Local persistence, migrations, constraints | Yes, fully | — |
| Supabase schema, RLS, sync | Yes, fully | — |
| Safety-officer exception workflow | Yes, fully | — |
| Audit, traceability, supersession | Yes, fully | — |
| Simulation mode | Yes, fully | Explicitly labelled, domain-isolated |
| CI/CD, flavours, signing, Play internal track | Yes | — |
| Accessibility, performance, security hardening | Yes | — |

The optical pipeline can be **genuinely validated** before any chemistry exists, using printed
colour targets photographed on multiple phones under multiple illuminants. That is dossier
V0. It is real evidence about the phone reader — which is software's question Q3 — and it is
the single most valuable thing the software team can do while waiting for the lab.

## Must wait for the laboratory

Every item is a *value*, not a *mechanism*. Each has a column waiting for it.

| Blocked | Depends on | Consequence until then |
|---|---|---|
| Calibration coefficients / LUT | V2 nominal calibration | No non-simulated dose can be produced. App returns `UNSUPPORTED_CALIBRATION`. |
| Limit of quantification | V2 blank distribution | `BELOW_QUANTIFICATION_LIMIT` boundary undefined |
| Saturation / upper range | V2 upper-range cells | `SATURATED` / `ABOVE_RANGE` boundary undefined |
| Uncertainty model | V2 + V7 residual analysis | No interval may be reported |
| Validated climate envelope | V4 | `ENVIRONMENT_OUTSIDE_VALIDATED_RANGE` cannot be evaluated |
| Read-by window after closure | V3 retention | Retention rule unenforced |
| Expiry patch boundary and false-valid rate | V6 ageing | `BADGE_EXPIRED` is date-only, not chemistry-backed |
| Blank / A1–A2 disagreement thresholds | V1–V3 | Consistency checks run with provisional thresholds, flagged as such |
| Colour-correction ΔE threshold | V0 on real substrate | Provisional from printed targets; revisit on real coupons |
| Final badge geometry and ROI coordinates | W4 cartridge design | Geometry is versioned data; a mock geometry is used meanwhile |
| Measured reference print values | Print lot production | Provisional values from a test print |
| Any accuracy or shelf-life claim | V7 blind validation, V6 ageing | **Nothing may be claimed.** |

## The rule that keeps this honest

Until a signed calibration model exists whose `permitted_domains` includes `field`, the app
cannot produce a field dose. Not "should not" — cannot, because the pipeline has no
parameters to run and the schema rejects a valid result with a null model reference.

This means the app is shippable to internal testing throughout, and is never one careless
merge away from reporting a fabricated number.

## For the SIH demonstration

Dossier §20 describes the right demo, and the architecture supports it directly: lab-prepared
specimens with concealed references, judge picks one, scan it, show the estimate with
uncertainty, then reveal the reference. Critically, it also says to **demonstrate refusal
deliberately** — a blurred image, an unsupported lot, a damaged dummy — and to keep printed
optical targets, simulated records and real gas-exposed specimens visibly distinct.

The three data domains, the labelled simulation banner and the refusal states are therefore
not compliance overhead. They are the demo.
