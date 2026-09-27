# Measurement engine — repository audit and M0 proposal

**Date:** 2026-09-23
**Scope:** directive §1 (audit), §59 (initial deliverable gate)
**Status:** gate document. No measurement code has been written. Awaiting approval.

---

## 0. Summary for the impatient

The repository is in better shape than a greenfield audit would assume. The **architecture for
the measurement engine is already specified in detail and is largely correct**; what is missing
is the implementation. `measurement-engine` contains 3 source files and no science.

The research pass did not mostly confirm the existing design. It surfaced **four findings that
change what must be built, and one of them is a hardware constraint that software cannot work
around.** Those are §3 below and they are the reason this document is worth reading before the
file list.

The directive's proposed repository layout conflicts with the layout this project already chose
and justified. I recommend **not** adopting the directive's layout, for stated reasons (§5).

---

## 1. What exists today — verified, not assumed

Commands run at audit time, from `measurement-engine`:

```
dart analyze   →  No issues found!
dart test      →  All tests passed!  (12/12)
```

### 1.1 Repository shape

```
app/                    Flutter application — 54 Dart files, 25 screens, worker workflow complete
measurement-engine/   Pure Dart scientific core — 3 files (see below)
docs/                   17 documents, 10 ADRs — architecture, CV spec, data model, design system
research/               6 PDFs (4 readable papers, 1 cover sheet, 1 scanned patent)
supabase/               migrations/ tests/ functions/ — all three EMPTY
tools/                  EMPTY
measurement-engine/badge-print/   EMPTY
assets/reference-colors/ EMPTY
.github/workflows/ci.yaml  format · analyze · test · build, per PR
```

Dart pub workspace, two packages. Flutter 3.47.5 / Dart 3.13.

### 1.2 The measurement core, in full

| File | Lines | Content |
|---|---|---|
| `lib/measurement.dart` | 9 | library exports |
| `lib/src/validity/result_status.dart` | 44 | `ResultStatus` enum — 18 states, classified `valued` / `censored` / `refused` |
| `lib/src/validity/measurement_result.dart` | 150 | `MeasurementResult` sealed union, `Dose`, `Uncertainty`, `ReasonCode`, `Provenance` |
| `test/validity/measurement_result_test.dart` | — | 12 invariant tests |

**That is the entire scientific core.** There is no imaging, no geometry, no colour science, no
feature extraction and no calibration code. `image: ^4.10.1` is declared as a dependency and is
currently unused.

### 1.3 What the existing core gets right

The `MeasurementResult` union is genuinely well built and directive §40/§38-compliant ahead of
schedule:

- Only `Valid` carries a `Dose`. `Refused` and `Censored` **have no field for one** — "convert a
  failure to 0.0 ppm·h" is not a bug that can be written, it is a type error.
- `Valid` asserts `provenance.calibrationModelId != null` — a dose without a model behind it
  cannot be constructed.
- `Uncertainty` requires a `basis` string, so a coverage claim cannot be made by omission. This
  directly implements §36.
- `Censored` retains a one-sided `bound`, so an above-range result keeps its information rather
  than discarding it.
- `Refused` and `Censored` assert `reasons.isNotEmpty` — a silent failure cannot be constructed.

This is exactly the §38/§40 contract, already compiler-enforced. **It should not be redesigned.**

### 1.4 Existing documentation that pre-empts the directive

| Directive section | Already specified in |
|---|---|
| §5 pipeline architecture | `docs/computer-vision/pipeline.md` — stage for stage |
| §7 versioned badge geometry as data | `docs/architecture/data-model.md` — `badge_geometries.roi_definition jsonb`, "no ROI coordinate appears in Dart source" |
| §8 fiducials / homography / reprojection error | `pipeline.md` §1–2 — normalised DLT, Hartley, SVD, condition number, residual gate |
| §9 camera guidance | `pipeline.md` §0 — full metric table |
| §10 image quality | `pipeline.md` §0 — variance of Laplacian, clipping fractions, glare |
| §15 held-out reference validation | `pipeline.md` §3.4 — **already specified, including the failure state** |
| §30 data domains | ADR-0006 — enum column, propagation trigger, calibration gate, environment separation |
| §31 dataset schema | `data-model.md` — essentially complete |
| §39 calibration package | `data-model.md` — `calibration_models` table, checksum, signature, `permitted_domains` |
| §41 immutability / supersession | `data-model.md` — insert-only, `supersedes_result_id`, UPDATE trigger |
| §47 simulated mode labelling | ADR-0006 — "SIMULATED — NOT A REAL H₂S MEASUREMENT", non-dismissible |

The held-out-patch requirement (§15) being *already present* in a document written before this
directive is a good sign about the project's instincts.

---

## 2. Reusable code

| Asset | Verdict |
|---|---|
| `MeasurementResult` / `ResultStatus` + tests | **Keep as-is.** Satisfies §38/§40. Extend only to add fields the pipeline needs (raw/normalised feature maps, quality sub-scores). |
| `docs/computer-vision/pipeline.md` | **Keep as the spec.** Amend for findings F-1…F-4. |
| `data-model.md` schema | **Keep.** Needs additions listed in §6.3. |
| Flutter design system, 25 screens, workflow state machine | **Keep, untouched.** Irrelevant to the engine; do not disturb. |
| CI workflow | **Keep.** The `measurement` job is already the blocking gate, which is the right shape. |
| `app/lib/features/workflow/**` simulation catalogue | **Reusable as an M0 consumer** — it already plays declared outcomes through the real result state machine. |

**Nothing needs to be rewritten to impose a new pattern.** Directive §1's warning does not bind
here because there is almost no engine code to rewrite.

---

## 3. Findings from the research pass — read this section

These are new. None appears in the existing architecture documents, and two of them are
blocking.

### F-1 — The badge must be a *type-1* passive sampler by construction, or ppm·h is not defensible **[BLOCKING — hardware]**

Source: `research/papers.md` P1 (Kiwfo et al. 2024 review), §1 and §4 of that paper.

Passive uptake is governed by diffusion across a boundary layer whose thickness varies with air
velocity. If the diffusion path is not fixed by the device's own geometry, the badge integrates
**deposition flux**, not concentration. The review calls these type-2 devices, notes that 11 of
14 reviewed devices are type-2, and states that for them "the application of Fick's law of
diffusion has sometimes been falsely used".

A wrist-worn badge with an exposed colour-changing patch, on a moving worker, in variable
refinery wind, **is a type-2 device**. Its endpoint colour encodes ∫(flux)dt, not ∫C dt.
Reporting ppm·h from it is the error the review names.

The two accepted remedies are physical: a gas-permeable membrane over the aperture (transport
becomes permeation), or porous plugs acting as a turbulence barrier. Either requires
**experimental determination of the uptake rate**, including its dependence on face velocity.

**Consequences:**
- This is a **cartridge/badge design requirement**, not a software one. No algorithm recovers it.
- The experimental plan needs a face-velocity sensitivity study. Uptake rate and its wind
  dependence become calibration-package fields.
- Until the badge is demonstrably type-1, the honest output unit is not ppm·h.

**Action:** raise with whoever owns the badge mechanical design, before the cartridge geometry
is frozen. Add `uptake_rate` and `face_velocity_domain` to the calibration package schema.

### F-2 — Several leading smartphone H₂S chemistries are *reversible*, and a reversible indicator cannot be a dosimeter **[BLOCKING — chemistry]**

Source: `research/papers.md` P1, describing Engel et al. 2021 (*Sens. Actuators B* 330, 129281):

> "In the cases of detection of NH₃ and H₂S, the indicator reactions are reversible. Therefore,
> only the momentary response to varying gas concentrations is obtained (and not the commonly
> achieved time-weighted values of passive sampling devices)."

QRsens (P2) is the same story: its H₂S sensor equilibrates in ~2 minutes and is read at
equilibrium.

A reversible indicator reports the concentration *now* and forgets the exposure history. It is
the opposite of an integrating dosimeter. If DoseBand's chemistry is selected by analogy to the
best-performing smartphone H₂S sensors in this literature, it will not integrate.

**Action:** irreversibility is a first-order chemistry selection criterion and must be stated as
such to the chemistry side. A "does the colour persist and not regress after the gas is removed"
experiment must precede any calibration work. (Carpenter's Cu-PAN → CuS route is a better
candidate on this axis since CuS is highly insoluble — but P4 also notes CuS is dissolved by HCl
produced in the reaction, so persistence must be measured, not assumed.)

### F-3 — Mercaptans cause a large false-positive H₂S reading on Cu-PAN chemistry **[BLOCKING — deployment risk at MRPL]**

Source: `research/papers.md` P4 (Carpenter et al. 2017), §3.4, quoted verbatim there. Natural
gas containing **0 ppb H₂S** turned the probe yellow and read **2.8 ppm H₂S**, attributed to
mercaptans at 1–10 ppm.

MRPL is a refinery. Mercaptans are ubiquitous in refinery gas streams and are the standard fuel
gas odorant. This is not a hypothetical interferent; it is an expected daily exposure that would
inflate a worker's recorded dose.

**Action:** mercaptan cross-sensitivity becomes a named, blocking item in the §33 interferent
matrix — not one row among many. If the selected chemistry shares the Cu-PAN failure mode, the
multi-zone architecture (§33: sensor A / sensor B / blank) stops being optional.

### F-4 — Single scalar colour features are empirically non-monotonic for H₂S

Source: `research/papers.md` P4, Table 1 (reproduced there in full). CIELAB b\* against H₂S
concentration rises, then falls monotonically 30→250 ppb, then jumps discontinuously at 400 ppb,
then rises. The authors state "there is no linear correlation in the range of 250–400 ppb" and
defend quantification on **range separation**, not monotonicity. a\* shows no trend at all; L\*
is flat and noisy.

Separately, QRsens (P2) had to hard-code "from 1 ppm onwards … add 1 unit to H_norm to avoid the
discontinuity" — hue is circular and wraps.

**Consequences:**
- §28's monotonicity test is empirically motivated, not ceremonial. It must gate feature
  selection.
- A model must never interpolate across a turning point. Monotonic interpolation over a
  non-monotonic response silently produces a plausible wrong answer.
- Circular features (hue) need circular handling — unwrapping against a reference, or sin/cos
  decomposition — never a magnitude threshold on the analyte.

### F-5 — A single reference patch cannot correct an illuminant, and its own authors' field data proves it

Source: `research/references/smart-form-analysis.md` §3. Same badges, same moment, natural vs
indoor light: 80 vs 61 ppb (130 % higher) and >120 vs 56 ppb (220 % higher).

This is the empirical case for §15 multi-reference correction **with withheld validation
patches** over the §13/§14 two-point baselines. It also means the QRsens and SmART-Form
baselines should be implemented as *comparators we expect to lose*, which is still worth doing —
they give the comparison a floor and cost ~60 lines each.

---

## 4. Missing components

Everything below is absent from the repository today.

### 4.1 Engine (all of it)

| Stage | Directive | Status |
|---|---|---|
| Frame quality metrics | §10 | absent |
| Fiducial detection | §8 | absent |
| Homography / DLT / SVD | §8 | absent |
| Perspective rectification | §5 | absent |
| Badge geometry as versioned data | §7 | schema designed, no loader, no geometry file |
| Reference patch sampling | §12 | absent |
| sRGB linearisation | §16 | absent |
| XYZ / CIELAB | §17, §18 | absent |
| ΔE76 / ΔE00 | §19 | absent |
| QRsens B/W correction | §13 | absent |
| SmART-Form ratio | §14 | absent |
| Multi-reference CCM + held-out residual | §15 | absent |
| ROI robust statistics | §12 | absent |
| Spatial / reaction-front features | §23 | absent |
| Feature vector definition + versioning | §24 | absent |
| Calibration model interface | §27 | absent |
| Monotonic LUT interpolation | §27 MODEL 0 | absent |
| Domain / censoring logic | §37 | absent |
| Pipeline orchestration → `MeasurementResult` | §40 | absent |

### 4.2 Infrastructure

| Missing | Directive | Note |
|---|---|---|
| `data/` with `simulated/ lab/ calibration/` | §30 | directory does not exist |
| `research/notebooks/` | §42 | does not exist |
| `research/references/` | §2 | **created by this pass** |
| Demo badge artwork + geometry file | §51 | `measurement-engine/badge-print/` is empty |
| Reference colour target definitions | §15 | `assets/reference-colors/` is empty |
| Fixture generator | §46 | `tools/` is empty |
| Test fixtures | §46 | `measurement-engine/test/fixtures/` does not exist |
| Camera capture in the app | §9, §11 | no `camera` dependency in `app/pubspec.yaml` |
| Supabase migrations | §31 | `backend/supabase/migrations/` empty |
| `CATALOG.md`, `LICENSE`, `CONTRIBUTING.md` at root | §0 | absent |

### 4.3 Pure-Dart linear algebra

ADR-0003 chose hand-written Dart over OpenCV. That decision is defensible and I am not
reopening it, but it has an unbudgeted cost the ADR understates as "~400 lines":

- **SVD** is needed for the normalised DLT (8×9 design matrix). A numerically sound SVD is not a
  weekend's work. The practical route is the Jacobi eigenvalue method on AᵀA, which is tractable
  and testable but must be written and validated against known decompositions.
- **Least-squares solve** for the CCM (§15) — normal equations plus Cholesky, or QR via
  Householder. Needs conditioning checks, because a degenerate reference set is a real failure
  mode we must *detect*, not absorb.
- **Monotonic interpolation** (PCHIP or similar) for MODEL 0.

Estimate: 700–1000 lines of numerical code with dense tests, not 400. It remains the right
call — a measurement pipeline whose arithmetic the defender can read is worth real money — but
it should be planned honestly.

---

## 5. Conflicts with the directive's proposed architecture

Directive §1.9 asks for these explicitly.

### C-1 — Repository layout: `measurement-engine/` vs `measurement-engine/`

The directive (§0, §43, §58) specifies root-level `measurement-engine/`, `research/`, `data/`,
`backend/`. The repository has `measurement-engine/`, `research/`, `supabase/`, `app/`,
`docs/`, `tools/`, justified in ADR-0004.

**Recommendation: keep the existing layout.** Rationale:

- `measurement-engine` **is** the measurement engine. Renaming it changes nothing about its
  contents and breaks the Dart pub workspace, the package import paths in ~54 app files, the CI
  job and the ADR.
- The workspace membership is what enforces the directive's own §44 boundary: `measurement`
  cannot import Flutter, so a dose cannot be computed in a widget. A root-level directory that
  is not a Dart package cannot enforce that.
- `supabase/` is more precise than `backend/` — it says which backend, and contains migrations,
  RLS policies and pgTAP tests that have no meaning under a generic name.
- Directive §1 says "Do NOT rewrite working code merely to impose a new pattern" and §58 says
  "Do not create an enterprise maze." Both cut toward leaving this alone.

**Adopt from the directive:** create `data/{simulated,lab,calibration}/` (§30) and
`research/{references,notebooks}/` (§2, §42). These genuinely do not exist.

**Add a root `CATALOG.md`** mapping directive concepts to their actual location, so a reviewer
following the directive can find everything. That resolves the conflict in documentation rather
than in a disruptive move.

### C-2 — Two languages for one set of features **[REAL RISK]**

Directive §42 wants Python/Jupyter research notebooks. ADR-0003 mandates pure Dart production.
Both are right, and together they create a hazard: **the same feature is computed twice, in two
languages, by two different implementations.**

A calibration model fitted on Python-computed CIELAB and applied to Dart-computed CIELAB is
fitted on different numbers than it is used with. The error is silent, systematic, and would
show up as inexplicable bias in field data long after the cause is forgettable.

**Mitigation, required before any model is fitted:** a shared golden-vector fixture set —
canonical inputs with expected outputs at every stage (linearisation, XYZ, Lab, ΔE00, CCM fit,
feature vector) — that **both** stacks must reproduce to a stated tolerance, checked in CI. This
is not optional overhead; it is the seam where a fitted model meets the code that uses it.

Tracked as risk R-3.

### C-3 — §51 puts the camera first; §58 puts Flutter integration eighth

Directive §51 (M0) begins "camera → fiducial detection → …". Directive §58's build order puts
"integrate Flutter" at step 8, after "reproduce their algorithms on sample/demo images",
"create deterministic CV pipeline", "build image-quality/refusal engine", "build feature
extraction" and "build calibration framework".

**Resolved in favour of §58.** M0 is proposed as engine-first on fixture images, headless, with
camera integration immediately after as M0b. Reasons: the engine is testable without a device;
the camera cannot be meaningfully tuned until the engine can say what a good frame is; and
`dart test` on fixtures is the fastest feedback loop available.

### C-4 — §27 model ladder vs ADR-0003's ML position

Directive §27 lists Random Forest and XGBoost as models 5 and 6. ADR-0003 admits ML only for ROI
localisation and contamination rejection, never as the dose estimator without evidence it beats
the deterministic baseline on unseen lots and phones.

**No real conflict.** §27 asks for an evaluation framework and §50 explicitly says not to decide
today. ADR-0003 states the bar that a tree model would have to clear. Both stand. Worth noting
that RF/XGBoost in Dart is not realistic — if one ever wins, it wins in Python and ships as a
serialised model with a Dart inference path, which is a significant additional decision.

---

## 6. Technical debt and gaps in the existing repository

### 6.1 Carried from `PROJECT_STATE.md` (still open)

1. No laboratory data exists — no coefficients, LoQ, saturation, uncertainty, climate envelope.
2. Badge geometry not frozen.
3. MRPL requirements unconfirmed.
4. The official problem-statement PDF has not been mechanically read (CID-encoded fonts).
5. No Supabase projects exist.
6. AGP 8.11.1 / Kotlin 2.2.20 deprecation pending (ADR-0008).
7. Disk headroom thin.
8. Goldens are macOS-rendered, excluded from Linux CI (ADR-0010).

### 6.2 Found during this audit

9. **`backend/supabase/migrations`, `backend/supabase/tests`, `backend/supabase/functions` and `tools/` are empty
   directories.** The schema in `data-model.md` is designed but not written. The constraint that
   the README advertises as a safety mechanism — `dose_only_when_valid` — **does not exist
   yet**. Today it is enforced only by the Dart type system.
10. `image: ^4.10.1` is declared in `measurement-engine/pubspec.yaml` but unused.
11. `measurement-engine/badge-print/` and `assets/reference-colors/` are empty; the design system
    references neither.
12. Root `LICENSE`, `CONTRIBUTING.md` and `CATALOG.md` do not exist (directive §0).
13. `research/` PDFs sit at the top level of `research/` with no index; two of the six are not
    readable sources (see F-6, F-7 below).

### 6.3 Schema additions the research pass makes necessary

| Addition | Driver |
|---|---|
| `calibration_models.uptake_rate`, `.face_velocity_domain` | F-1 |
| `badge_batches.reversibility_verified` (or on `formulations`) | F-2 |
| `feature_definition.monotonic_domain` — the interval over which a feature is certified monotonic | F-4 |
| `optical_features` to store **both** raw and corrected values | §13 |
| Interferent test results linked to formulation, with mercaptans named | F-3 |

### F-6 — `research/Laboratory Validation … Hydrogen Sulfide in Air.pdf` is a cover sheet only

1 220 bytes of extractable text: title, authors, DOI, "Article views: 3". **No article body.**
It is also not the paper the directive mandated — it is Kring et al. 1984
(10.1080/15298668491399271), whereas §3.5 asks for 10.1080/15459624.2014.916808.

### F-7 — `research/WO2021146271A1.pdf` is a scanned image with no text layer

83 pages, no OCR layer (`pdftotext` yields 83 bytes). Readable only as rendered images.
Identified by rendering page 1 — see §8 below, this is a live IP matter.

---

## 7. Scientific assumptions currently embedded in the project

Each of these is an assumption, not a finding. They are listed so they can be attacked.

| # | Assumption | Status |
|---|---|---|
| A-1 | The badge integrates exposure, so endpoint colour encodes ∫C dt | **Challenged by F-1.** True only if type-1. |
| A-2 | The chemistry is irreversible over a shift | **Challenged by F-2.** Unverified. |
| A-3 | Reciprocity holds: equal C×t gives equal endpoint state | **Untested.** §26 gate. SmART-Form asserts it but tested it only weakly (all runs 72 h, constant concentration). |
| A-4 | Optical response is monotonic over the validated range | **Challenged by F-4.** |
| A-5 | Printed reference patches suffice to normalise the illuminant | Partially challenged by F-5; multi-patch + held-out is the mitigation, and its adequacy is itself an experiment (V0). |
| A-6 | Wrist exposure is a usable proxy for breathing-zone exposure | **Known false in general** (documented as C5 in `docs/requirements/open-questions.md`). Handled by disclosure, not correction. |
| A-7 | A phone camera can resolve the required colour differences across device models | **Untested.** This is dossier V0 and is the most valuable experiment available before chemistry exists. |
| A-8 | Deterministic CV suffices; no ML needed for localisation | Assumed in ADR-0003, with named revisit triggers. |

---

## 8. Open legal questions — for counsel, not for engineers

### L-1 — WO 2021/146271 A1 (Ohio State Innovation Foundation)

`research/WO2021146271A1.pdf`, front page read directly. "Colorimetric sensor for detection of a
contaminant in the indoor environment and related systems". Inventors Dannemiller, Qin,
Parquette, Gouma — **the SmART-Form authors**. Filed 2021-01-13, priority 2020-01-13.

Figure 1 shows: **reaction area (102)**, a graded **calibration area (104)**, and **coded
markers (106) at the corners**. Google Patents describes the disclosure as covering "at least one
coded-marker" optionally a QR code, on "3 or more corners", and a "multi-color calibration area"
with "a plurality of regions, each region having a different color or a different tint or shade
of the same color", together with a colour-ratio computation.

That is, on its face, the badge architecture this directive describes for DoseBand.

**What I could establish:** the PCT publication exists, its figures, and that Google Patents
marks the PCT application "Ceased" — which is expected and uninformative, since the international
phase always lapses at ~30 months.

**What I could not establish:** whether national-phase applications were filed, where, and
whether any granted. My searches did not resolve it, and I am not going to guess at an
application number or a status.

**This needs a freedom-to-operate opinion from a patent attorney, covering at minimum India,
before the badge artwork is frozen.** The claims are directed to formaldehyde and allergens;
H₂S is a different analyte, and claim scope may or may not reach us. That judgement is not mine
to make.

### L-2 — SmART-Form is GPL-3.0

Copying or translating that source into `measurement-engine` would make the distributed app a
derivative work under GPL-3.0. **Recommendation: do not use the source at all.** Implement from
the published equations and our own design; record in `CATALOG.md` that no SmART-Form code was
copied. Nothing in the teardown requires its code — the algorithm is nine lines and we need a
better one. Details in `research/references/smart-form-analysis.md` §4.

### L-3 — IBM repository is BSD-3-Clause

Permissive and usable. Retain copyright notice and clauses; do not use IBM's name for
endorsement. Any Dart function derived from `uIPL_2022_v2.py` carries a provenance header naming
repository, commit, source function and licence. Details in
`research/references/ibm-colorimetry-analysis.md` §5.

L-2 and L-3 are engineering readings of the licences, not legal advice.

---

## 9. Risks

| ID | Risk | Severity | Mitigation |
|---|---|---|---|
| R-1 | Badge is type-2; ppm·h is not defensible | **Critical** | F-1 to badge design now, before cartridge freeze |
| R-2 | Chemistry is reversible; not a dosimeter | **Critical** | F-2 persistence experiment before any calibration work |
| R-3 | Python research / Dart production feature drift | **High** | Cross-language golden-vector fixtures in CI, before any model is fitted (C-2) |
| R-4 | Mercaptan false positives at MRPL | **High** | F-3; named in the interferent matrix; may force multi-zone badge |
| R-5 | Patent exposure on badge architecture | **High** | L-1 — FTO opinion before artwork freeze |
| R-6 | Non-monotonic feature silently interpolated | **High** | §28 monotonicity gate enforced in the calibration model loader, not just in analysis |
| R-7 | Pure-Dart SVD/least-squares is harder than ADR-0003 budgeted | Medium | Plan 700–1000 lines; validate against published decompositions; ADR-0003's revisit triggers stand |
| R-8 | Reciprocity fails | **Critical to the product claim** | §26 gate. If it fails, report exposure bands, not point values — decide *before* the demo, not after |
| R-9 | P5 (liquid-crystal badge) never obtained | Medium | It is the only mandated source describing a real cumulative H₂S badge; acquire via institutional access |
| R-10 | SIH deadline pressure produces a number where a refusal is correct | **Critical** | Already mitigated structurally by the result union and calibration gating; keep it that way |

---

## 10. Dependencies

### Already present
`image` (decode; currently unused), `meta`, `test`, `lints`.

### Required for M0 — pure Dart, no new packages
Linear algebra written in-package (SVD via Jacobi on AᵀA, least-squares, PCHIP). No new
dependency is proposed. This is deliberate: adding `ml_linalg` or similar would trade auditable
code for an opaque one, against ADR-0003's reasoning.

### Required for M0b (camera)
`camera` (first-party, already named in `docs/architecture/overview.md`), `mobile_scanner` for
QR. Both already planned; neither is in `app/pubspec.yaml` yet.

### Required for the research stack (§42)
Python 3.11+, `numpy`, `opencv-python`, `scikit-image`, `scikit-learn`, `pandas`, `matplotlib`,
`jupyter`. Isolated under `research/`, never a build dependency of the app.

### Explicitly not proposed
OpenCV in the app (ADR-0003), any ML runtime, any cloud inference.

---

## 11. Proposed implementation order

Following directive §58, with C-3 resolved in favour of engine-first.

| Step | Work | Gate |
|---|---|---|
| **0** | **This document.** Audit, teardowns, literature record. | ← you are here |
| **0b** | Raise F-1, F-2, F-3 with badge/chemistry owners. Request FTO opinion (L-1). Acquire P5. | Not software-blocking, but F-1/F-2 can invalidate the product claim, so they start now |
| **M0** | Deterministic engine on synthetic fixtures, ending in `MeasurementResult`. §51. | `dart test` green; no dose claim |
| **M0b** | Camera capture + live guidance in `app/`; real photographs of a printed demo badge. | Dossier V0 begins |
| **M1** | Python research pipeline over a folder of labelled images → `features.csv` + plots. §52. | Cross-language golden vectors agree (R-3) |
| **M2** | Model comparison on real calibration data. §53. | Grouped held-out splits only |
| **M3** | Reciprocity and robustness. §54. | **§26 gate — go/no-go on the ppm·h claim** |

**M2 and M3 cannot start.** They require laboratory data that does not exist. M0, M0b and M1 are
fully buildable now and assert nothing about chemistry.

---

## 12. M0 — exact proposed implementation

**Scope:** an artificial demo badge, synthetic fixtures, headless. Produces a `MeasurementResult`
from a fixture image through the full deterministic chain. **Makes no H₂S claim whatsoever** —
the only calibration model present is explicitly `simulated`-domain.

### 12.1 New files in `measurement-engine/`

```
lib/src/
  geometry/
    badge_geometry.dart        BadgeGeometry value type + JSON loader. Versioned. mm space.
    fiducials.dart             Bradley adaptive threshold → connected components →
                               area/aspect/fill filter → intensity-weighted sub-pixel centroid
                               → identify 4 by relative geometry, asymmetric marker fixes rotation
    homography.dart            Hartley normalisation → 8×9 DLT → SVD (Jacobi on AtA) → H
                               + condition number, determinant sign, reprojection residual
    rectify.dart               inverse warp, bilinear sampling, fixed px/mm
  linalg/
    matrix.dart                small dense matrix ops
    svd.dart                   Jacobi eigenvalue decomposition of AtA
    least_squares.dart         normal equations + Cholesky, with conditioning check
    interpolate.dart           PCHIP monotonic interpolation
  quality/
    frame_quality.dart         variance of Laplacian; clipping fractions per channel;
                               specular fraction; resolution vs required px/mm
    quality_gates.dart         PROVISIONAL thresholds, each carrying a `provisional: true`
                               marker and the evidence it awaits
  colour/
    srgb.dart                  linearise / delinearise (§16)
    xyz.dart                   linear RGB ↔ XYZ, D65 (§17)
    lab.dart                   XYZ ↔ CIELAB (§18)
    delta_e.dart               ΔE76 and ΔE00 (§19)
    correction_qrsens.dart     §13 both forms, with denominator validity guard
    correction_ratio.dart      §14 SmART-Form ratio and difference
    correction_ccm.dart        §15 3×3 and 3×4 affine least-squares CCM
    correction_residual.dart   §15 held-out patch ΔE00 → REFERENCE_PATCH_FAILURE
  features/
    roi_sample.dart            erosion margin, specular mask, trimmed/median statistics (§12)
    feature_vector.dart        named, versioned feature set (§24) — raw and corrected kept apart
  calibration/
    calibration_model.dart     interface: fit / predict / validateDomain / serialize / load (§27)
    lut_model.dart             MODEL 0 — monotonic LUT interpolation
    monotonicity.dart          §28 — certify/refuse a feature's monotonic domain
    domain_check.dart          §37 — censoring: below LoQ / above range / saturated
  pipeline.dart                orchestration → MeasurementResult, with progress states (§44)
```

### 12.2 New files elsewhere

```
tools/
  generate_fixtures.dart       synthetic badge renderer: known dose levels, applied perspective,
                               simulated illuminants, glare, defocus, noise, damaged patches
measurement-engine/badge-print/
  demo-badge-v0.svg            artificial demo badge artwork (NOT the product badge)
  demo-badge-v0.geometry.json  versioned geometry — the only place ROI coordinates live
data/
  simulated/  lab/  calibration/   with a README stating the §30 rule
research/notebooks/            scaffold only at M0; populated at M1
CATALOG.md                     directive concept → repository location map (resolves C-1)
```

### 12.3 Tests (the actual deliverable)

Per directive §46. Every one runs headless under `dart test`.

- **Colour science against published vectors.** sRGB linearisation, XYZ, CIELAB round-trips,
  ΔE76, and **ΔE00 against the Sharma et al. test-vector set** — ΔE00 is notoriously easy to get
  subtly wrong and must not be trusted to its own implementation.
- **Geometry.** Known homography → apply → recover → compare. Rotated, perspective-skewed,
  scaled fixtures. Reprojection residual rises with induced bend.
- **Correction.** Synthetic illuminant shift → CCM recovers known patch values; held-out residual
  stays low. Then a *deliberately wrong* reference profile → residual exceeds threshold →
  `REFERENCE_PATCH_FAILURE`.
- **Refusal paths, one test each:** blur, glare, clipped channel, missing fiducial, damaged
  reference patch, insufficient resolution, missing calibration, incompatible batch.
- **Result invariants:** existing 12 tests, extended — below LoQ, above range, saturated each
  produce `Censored` with a bound and no dose.
- **Monotonicity:** a synthetic non-monotonic feature is *refused certification* by
  `monotonicity.dart`. This test exists because of F-4.

### 12.4 Explicitly out of scope for M0

No camera. No Supabase. No real badge. No H₂S chemistry. No fitted model — the only calibration
artefact is a hand-written simulated LUT whose `permitted_domains` is `[simulated]`, so by
construction it cannot produce a field result. No accuracy claim of any kind.

### 12.5 What M0 proves

That the architecture executes end to end; that every stage is fixture-testable; that the
refusal paths actually fire; and that the result contract holds under a full pipeline rather than
only in unit tests. Nothing about H₂S.

---

## 13. Hostile review at this gate (§57)

Answered honestly for the state as it is today, not as it is intended to be.

| # | Question | Answer now |
|---|---|---|
| 1 | What exactly is being measured? | Intended: cumulative external H₂S exposure, ppm·h. **Actually, per F-1, an unmitigated badge would measure accumulated deposition flux.** Unresolved. |
| 2 | Concentration, average, or cumulative dose? | Cumulative dose is the primary output; C_avg only as D/T with both validated. The contract already enforces this. |
| 3 | Where does ground truth come from? | Nowhere yet. No lab data exists. §25 forbids inferring it from the badge. |
| 4 | Could lighting explain the response? | **Yes, today.** F-5 shows 130–220 % swings from lighting alone in the nearest prior art. Mitigation designed (multi-patch + held-out), not yet built or validated. |
| 5 | Could phone model explain it? | Unknown. Untested. This is V0 and is the most valuable pre-chemistry experiment. |
| 6 | Could humidity explain it? | Unknown for our chemistry. P4 found no RH effect 25–82 % for Cu-PAN; P3 found formaldehyde badges unusable above 75–80 % RH. Chemistry-specific. |
| 7 | Could batch variation explain it? | Unknown. Batch is in the schema; no batches exist. |
| 8 | Does calibration extrapolate? | No — `validated_range` with censoring is specified, and no model exists to extrapolate. |
| 9 | Is the model leaking train/test? | No model exists. The leakage pattern to avoid is documented (IBM's `train_test_split(shuffle=True)`); our rule is grouped splits by physical unit. |
| 10 | Does equal dose at different C×t give equal response? | **Untested, and this is the product's central claim.** §26 gate, milestone M3. |
| 11 | Can an interferent produce the same colour? | **Yes, demonstrably** — F-3, mercaptans reading 2.8 ppm at zero H₂S on Cu-PAN. Highest deployment risk at a refinery. |
| 12 | Can an expired badge appear valid? | Today, expiry is date-only. The expiry patch → failure correlation needs the ageing study (V6). |
| 13 | What happens when references are damaged? | Designed: `REFERENCE_PATCH_FAILURE` via held-out residual. **Not built.** |
| 14 | What happens when the sensor saturates? | Designed: `Censored(saturated)` with a lower bound. **Not built.** |
| 15 | What happens when the model is uncertain? | `Uncertainty` requires a stated `basis`; no coverage may be claimed without evidence. Enforced by the type. |
| 16 | Can we reproduce an old result exactly? | Designed — `Provenance` carries algorithm/geometry/calibration/app/device versions, results are insert-only with supersession. **The database implementing this does not exist yet** (§6.2 item 9). |
| 17 | Is every accuracy number backed by held-out data? | There are no accuracy numbers anywhere in this repository. That is correct and must stay true. |
| 18 | Breathing zone or wrist? | **Wrist.** Known non-equivalent, documented as C5, handled by disclosure. Note P1 records the same finding independently: in the Choi ozone field study, room concentration and personal exposure "evidenced a significant disparity". |
| 19 | What evidence supports each compensation term? | None yet, and none is applied. No environmental compensation exists — correctly, per §32. |
| 20 | Would a simpler model do as well? | The plan already starts at the simplest (MODEL 0, monotonic LUT) and requires evidence to move up. F-4 makes even that non-trivial. |

The uncomfortable summary: **questions 1, 10 and 11 are open, and any one of them can invalidate
the ppm·h claim.** They are physical and chemical questions, not software ones. The software's
job at this gate is to be ready to measure honestly if the answers come back well, and to refuse
if they do not — which is exactly what the architecture is arranged to do.

---

## 14. Recommendation

Approve M0 as scoped in §12, and start §11 step 0b in parallel, since F-1 and F-2 can
invalidate the product claim independently of any code.

**Do not** adopt the directive's repository layout (C-1). **Do** create `data/`,
`research/notebooks/` and `CATALOG.md`.

Nothing in M0 asserts anything about H₂S, so M0 is safe to build while F-1 and F-2 are being
answered.
