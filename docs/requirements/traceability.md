# Requirements traceability

Source of truth for the brief is the official SIH26118 listing. The listing PDF in the
user's possession (`PS-H2S.pdf`) uses CID-encoded fonts and could not be text-extracted
mechanically; this matrix is traced against the verified transcription in
`SIH26118_H2S_Research_and_Engineering_Dossier.md` §1, which states the screenshots and
pasted statement agree with the official entry. **Action: one human should re-read the
official listing and confirm this matrix before submission.**

Legend — **SW** = software's responsibility, **HW/CHEM** = physical system, **LAB** = must
be established experimentally.

## A. Brief deliverables

| # | Brief deliverable | Owner | Software obligation | Traced to |
|---|---|---|---|---|
| R1 | Disposable wristband | HW | Badge identity + assignment lifecycle only | `badges`, `badge_assignments` |
| R2 | Progressively changing H₂S strip | CHEM | Extract optical features from active ROI(s) | CV §8 |
| R3 | Separate shelf-life patch | CHEM + SW | Read expiry ROI; map to validity state; refuse when aged | CV §8, State machine `BADGE_EXPIRED` |
| R4 | Printed reference scale | HW + SW | Use measured print values for colour correction; hold patches out to test it | CV §6–7 |
| R5 | Phone-based quantitative estimate | **SW** | Full capture → rectify → correct → features → calibration → dose | CV §1–9 |
| R6 | Worker / shift records | **SW** | Offline-first records, roles, audit, versioned results | Data model |
| R7 | Experiments at known concentration and duration | LAB | Ingest lab datasets; build calibration models from them | Phase 10 |
| R8 | Uncertainty explicitly permitted | **SW** | Every valid result carries an uncertainty and a coverage statement | Result contract |
| R9 | Temperature / humidity effects addressed | LAB + SW | Record environment; refuse outside validated envelope | `ENVIRONMENT_OUTSIDE_VALIDATED_RANGE` |
| R10 | Stated, validated shelf life | LAB + SW | Enforce use-by, seal and lot status before producing a number | Validity engine |

## B. Four questions the programme must answer (dossier §1)

| Q | Question | Can software answer it? |
|---|---|---|
| Q1 | Does gas reaching the strip represent intended exposure? | **No.** Sampling physics. Software only records placement and coverage. |
| Q2 | Does chemical change retain a reproducible record? | **No.** Chemistry. Software enforces the read-by window once LAB defines it. |
| Q3 | Can a phone recover the estimate with characterised uncertainty? | **Yes — this is the software's question.** |
| Q4 | Can the validity indicator warn before degraded chemistry misleads? | **Partly.** LAB establishes correlation; software enforces the boundary and refuses. |

Software owns Q3 outright and the enforcement half of Q4. It cannot contribute to Q1 or Q2,
and must not present outputs as if it could.

## C. Directive requirements → design location

| Directive § | Requirement | Where satisfied |
|---|---|---|
| 2 | Three data domains never mixed | Data model §Domain; ADR-0006; separate Supabase projects |
| 3 | RBAC, four roles | Data model §Identity; RLS policies |
| 4 | Core workflow incl. interrupted flows | Architecture §Workflow & recovery |
| 5 | Result state machine, never 0 ppm·h on failure | Result contract; DB CHECK constraint |
| 6–8 | Design system, industrial identity, semantic tokens | `docs/design/` (Phase 1) |
| 9–10 | Role-specific navigation, actionable home | Architecture §Navigation |
| 11 | Camera as its own product | CV §2 + Phase 3 |
| 12–13 | Deterministic CV, colour science | `docs/computer-vision/pipeline.md` |
| 14 | Versioned calibration model, never in UI code | Package boundary: `measurement-engine` has no Flutter import |
| 15 | Full measurement traceability, supersede not overwrite | Data model §Results |
| 16 | Offline-first | Architecture §Offline |
| 17–18 | Supabase, normalised schema, DB constraints | `docs/architecture/data-model.md` |
| 19–21 | Security, privacy, QR payload | Architecture §Security |
| 22–24 | History classes, exception-led officer UX, sparing notifications | Architecture §Screens |
| 25 | Simulation mode, visibly marked, non-contaminating | ADR-0006 |
| 26–27 | Testing strategy, device matrix | `docs/architecture/testing-strategy.md` |
| 28–31 | Performance, accessibility, failure UX, observability | Phase 12 + design system |
| 32–35 | CI/CD, Play release, permissions, flags | Architecture §Delivery |
| 36–38 | Architecture without ceremony, justified deps, one state solution | ADR-0001, 0003, 0004 |

## D. Claim boundaries the software must enforce in its own copy

These are hard constraints on user-visible text, not style preferences. Drawn from dossier
§2 and §15.

- The measured quantity is **external H₂S concentration integrated over time, in ppm·h**.
  Never "dose absorbed", never a health outcome, never a probability of harm.
- The badge **supplements** certified real-time alarms. It cannot detect a dangerous peak.
  Never generate an acute-danger notification from a badge reading.
- No interval is labelled "95%" unless independent data support that coverage.
- Scan quality is **not** the probability that a worker is safe. Never conflate the two.
- Never present the device as DGMS-approved, OISD-certified, NABL-certified or medical grade.
- Never sum two readings from one badge. A badge reports one cumulative total; a later read
  supersedes an earlier one, it does not add to it.
