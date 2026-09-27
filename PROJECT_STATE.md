# PROJECT_STATE

**Product:** H₂S DoseBand — passive colorimetric cumulative H₂S exposure badge + phone reader
**Programme:** SIH 2026 / PS 26118 (MRPL) · Idea deadline 30 Sep 2026
**Updated:** 2026-09-27 (APP-PRODUCT-01 Phase 0)

## Current phase

**APP-PRODUCT-01 Phase 0 — product foundation — complete, awaiting review.**
Branch `app-product-01`, from checkpoint `75bb983` (MEASUREMENT-INTEGRATION-02).

- **Design system v2** (`docs/design/design-system-v2.md`): white-first light
  theme; brand green derived from the logo asset (`#5C822D` → primary
  `#527823`); one token source, one radius scale, breakpoints, elevation. The
  primary action was white on orange at 2.88:1 and is now brand green at
  5.16:1. Brand is never a status colour — tested.
- **Worker navigation:** Home · History · **Scan** · Safety · Profile, a
  floating bar with a centre Scan action; a rail at ≥720. Research and
  developer tools moved from `/profile/*` to `/dev/*` (dev builds only), with
  a component catalog at `/dev/components`.
- **Domain foundation:** DoseBand + lifecycle policy, MonitoringSession +
  policy, one provenance vocabulary mapped from every existing type,
  connectivity/sync states, role/scope/permission/data-class policy (design
  contract — server enforcement pending), a DoseBand registry contract with
  typed claim outcomes and only a not-connected implementation.
- **Product documents:** `docs/product/product-foundation-v1.md`,
  `role-permission-matrix.md`, `online-offline-matrix.md`,
  `screen-rationalization-inventory.md`; `docs/engineering/ui-foundation-debt.md`.
- **Guards:** gradients, literal colours, Material hues, wall-clock reads,
  mandatory route `extra`, presentation names — all ratchets.
- Tests: 1,063 app (baseline 714), 312 measurement, 394 parity. 27 foundation
  goldens; 49 legacy goldens updated after visual review. A new sweep renders
  every parameterless route at 320×568 at 100% and 200% text.
- `measurement-engine` unchanged. M0C, S1, S2, S3 remain **OPEN**.

Earlier phase notes follow.

**Phase 1 complete. Phase 2 in progress.** Design system implemented, worker navigation
shell built. The simulated worker workflow now runs **end to end** (Section 81): launch →
login → home → work context → badge assignment → verification → pre-work check → start →
active monitoring → end → guided scan (simulated) → processing → result → measurement detail →
history. Riverpod introduced for the workflow state machine, persisted through a narrow store
interface (in-memory now; Drift behind the same seam in Phase 6). The app still has no camera,
no backend, no dose inference, and makes no claim about chemistry — every specimen carries a
declared outcome that plays through the real `MeasurementResult` state machine, all in the
`simulated` data domain and visibly marked. See `docs/design/screen-inventory.md`.

Also fixed: `flutter run` (bare) had no `main()` in `lib/main.dart`, which produced "Could not
create root isolate". `main.dart` now boots the dev flavour by default.

**Cold-start persistence is done.** Every workflow transition is written to a JSON snapshot in
the application-support directory before the UI advances, and the monitored period is restored
at launch — a worker whose phone is killed mid-shift comes back to the same period, badge and
stage. Writes are atomic (temp + rename). Decoding refuses rather than repairs: a foreign
schema, a truncated file, an unknown badge, a stage missing what it requires, or a stored dose
without a calibration model all fall back to an empty session rather than a guessed one.
See `docs/design/persistence.md`.

Persisting timestamps made clock trust a real problem, so the honest part of it shipped with
it: a window that runs **backwards** is proof the device clock moved, and `coverageAt` now
returns null rather than clamping to `Duration.zero`. The screens print `- - -`, and a scan
over such a window returns `Refused(resultUnreliable, EXPOSURE_WINDOW_UNTRUSTED)` instead of
the specimen's declared dose. Exposure duration multiplies into ppm·h, so "0 h 00 min" in
place of an unknown window was a plausible number standing in for an absent one.

**MRPL work context is done (WORK-CONTEXT-01).** The vertical slice runs end to end: auth →
worker home → work context → badge assignment → pre-work dosimetry check → active monitoring,
with the context persisting across a cold start alongside the workflow state. Worker identity,
site, department, work area, shift, job, PTW reference, JSA reference and the toolbox-talk
acknowledgement are all typed domain objects rather than strings, validated centrally by
`WorkContextValidator`, and frozen as measurement provenance the moment monitoring starts.

Every enterprise-linked value carries an `EnterpriseValue<T>` recording whether it is demo
data, typed on the device, or confirmed by an external system. Only the first two are
producible today. "Verified" cannot be constructed without naming the system, reference and
timestamp that back it, and the persistence decoder refuses a snapshot claiming verification
without them — so editing one word in the stored file cannot turn a typed-in permit number into
one MRPL confirmed. See `docs/product/work-context.md`.

The wording boundary is now enforced by a test rather than by care:
`test/workflow/safety_language_test.dart` scans every non-comment line of `lib/` for "safe to
work", "PTW approved", "JSA approved", "work authorised", "MRPL verified" and similar, and
asserts its own patterns still catch a clear breach. The strongest claim any screen makes is
"Ready for dosimetry", which is a statement about DoseBand's own readiness and is shown next to
copy saying it does not authorise work or replace PTW, JSA or site safety requirements.

**Worker Home was rebuilt** after review: it had been a title, a blank area and one button.
It is now a state-aware dashboard — hero, identity, today's shift, work context, monitoring
status, one contextual action, status strip, quick actions — with ten states sharing one
architecture. Missing data produces an empty *value*, never an empty screen, so a worker can
see what a monitored period still needs. See `docs/design/worker-home.md`. Verified on a real
iPhone 16 Pro simulator, not only in goldens.

**APP-INTEGRATION-01 — the app is ready for the first physical badge.** An
installable Android build (`dist/doseband-m0c-ready-0.2.0+2-dev-release.apk`)
now carries the whole optical path to disk: real camera → guidance → still →
fiducials → homography → sensor, blank, expiry and reference ROIs → correction
validated on withheld patches → features → a typed `unsupportedCalibration`
refusal → an archived research record with the original bytes. Profile →
**Physical capture test** is the bench workflow; **Research captures** exports
and compares X0–X3.

The audit found the pieces existed but were not connected. The capture archive
was never called, so every image would have been discarded; the phone model was
recorded as the camera id (`"0"`); preview guidance judged px/mm on a ¼-scale
frame against full-scale limits and could never report *ready*; and live
guidance never resumed after the first capture. All four are fixed and covered
by 16 end-to-end tests that push encoded JPEG bytes through the app's own
controller, recorder and archive.

A `Calibration` interface now sits between optical features and a result.
`NoCalibration` is its only implementation, and `calibrationMismatch` refuses a
simulated calibration on a real capture. Hostile review of Profile removed a
hard-coded "Pending: 2" sync count for a backend that does not exist and a wrong
algorithm version. The worker's Scan tab is still simulated, deliberately: its
badge is a simulated specimen, and wiring a real photograph into it would attach
real optics to a simulated identity.

Not run on a device — the attached phone stayed `unauthorized`. The APK was
built from an uncommitted tree; commit before the session. M0C, S1, S2, S3
remain OPEN. See `docs/engineering/`.

**M0C IS BLOCKED — PHYSICAL EVIDENCE REQUIRED (M0C-REAL-WORLD-OPTICAL-VALIDATION).**
The preflight found two independent blockers. There is no physical Android
device attached (`adb devices` empty, `flutter devices` shows only macOS and
Chrome), and M0C cannot be satisfied by a simulator, a mock camera or synthetic
fixtures. Separately, both configured printers are monochrome laser, and six of
Badge V1's ten reference patches are chromatic — a monochrome print reproduces,
in physical form, the rank deficiency M0A established algebraically for a
neutral-only reference set. That blocks the colour half of M0C even once a phone
exists; the geometry half would survive. Recorded as ADR-0011.

Preparation was done so the first hour with hardware is spent capturing rather
than deciding: an A4 print sheet generator (four specimens, a 100 mm scale bar,
and a printed record block for printer, paper, mode and measured dimensions), a
threshold inventory recording all 21 capture and quality thresholds as
`SYNTHETIC ONLY`, and a capture protocol covering the matrix, dataset layout,
session-wise splitting and the limits on what may be claimed about colour
without a spectrophotometer. `measurement-engine` was not modified — §66
permits an engine change only on physical evidence, and there is none.

M0C, S1, S2 and S3 all remain OPEN. No H₂S was involved; M0C requires none.

**UI-SURFACE-01 IS FROZEN (UI-SURFACE-01-FINAL-AUDIT).** The application was
reviewed horizontally as one product rather than six modules. Ten defects were
fixed and three deferred with rationale; the full register is
`docs/design/final-ui-audit.md`, and what is UI-complete but not functional is
separated out in `docs/design/functional-gaps.md`.

Two findings were structural rather than cosmetic. Twelve detail routes wrote
`state.extra!` and threw an uncaught exception whenever they were deep-linked,
typed or restored from a cold start; they now share one guard and a screen that
explains what is missing and offers a way back. And every UI test that looped
routes inside a single `testWidgets` body had been exercising only its first
route, because `DoseBandApp` builds its router once and pumping it again reused
the old `State` — so a test that named twenty routes asserted twenty times
against route one. Adding `key: ValueKey(route)` to all eighteen affected test
files turned 641 green tests into 641 green and 21 red, and every one of those
reds is recorded as its own defect. That is the most consequential result of the
phase: a meaningful share of the honesty coverage had not been running.

The shared emphasis treatment also changed. `InfoCard(emphasis: true)` drew the
corporate green, and three of its four uses sit on statements of absence — "No
production H₂S calibration available" chief among them — where green reads as
approval of the sentence it surrounds. Emphasis is now neutral ink at double
width; `selectedBorder` keeps its green for genuine selection.

A whole-application claim sweep now runs every prohibited phrase — safety,
regulatory, security, calibration, maturity, zero-collapse — against all 74
routes, with a matcher that ignores negations so the product's many denials
("No validated calibration model exists") are not flagged as the claims they
refute. 664 app tests, 269 measurement tests, 394 parity comparisons, all green.

**The Admin surface is complete (UI-SURFACE-01-ADMIN).** Nineteen routes across governance,
organisation, measurement and system. Its purpose is the opposite of most administration
screens: it makes unfinished infrastructure *more* visible, not less. Administration home
opens on a count of what exists — 0 of 11 integrations connected, 0 of 3 devices validated,
0 of 6 retention policies configured, no calibration installed, no records synchronised — in
the ordinary text colour, neither green nor red.

Four honesty properties are enforced in the type system rather than by care:
`IntegrationState` has no `connected` value, so no screen can slip into one;
`AdminIntegration.lastSuccess` is null by construction, so no fabricated sync event can be
shown; `RetentionProfile.duration` is null, so no retention period can be asserted as
configuration; and `DeviceValidationState.validated` exists with nothing in it, because M0C
is open. Calibration administration's Import, Activate and Supersede controls are permanently
disabled — an admin control that could switch on quantitative output would be a path around
scientific validation. Thirty-seven tests cover it, including one that rejects any numeric
figure with a unit on the calibration screen and one that rejects compliance language
("ISO 27001", "GDPR compliant", "audit ready", "production ready") across every admin route.
Captured on an iPhone 16 Pro simulator: `docs/design/screenshots/admin/`.

**The Reporting surface is complete (UI-SURFACE-01-REPORTING).** The occupational exposure
register is its backbone: the full occupational field set, ten filters, cards on a phone and a
data table on a wide layout, with a thirteen-step traceability view behind every record —
worker → shift → area → job → PTW/JSA → badge → monitoring window → read → measurement →
validity → calibration version → HSE review → audit. A report builder, preview, audit-package
builder and export history complete the subsystem.

**This phase introduced the product's first quantitative figures, and constrained them in the
type system.** `SimulatedExposure` has one constructor and always marks its value simulated;
`ReportedMeasurement` declares which states may carry a quantity at all; `MeasurementCell.of`
**throws** if a record presents a figure its state is not entitled to. Every surface formats
through that one path, so no reading, below-quantification, above-range, saturated, partial and
unsupported-calibration cannot be collapsed into `0` by a table, a chart or an export. Above
range stays distinct from saturated; partial stays distinct from complete. No mean or total is
reported anywhere, because averaging a set containing unknowns would require treating them as
something.

Template profiles carry their caveat as data — OISD-aligned and DGMS-aligned say in the type
that nothing has been verified and no regulator has reviewed DoseBand. Export is disabled
throughout; the preview is headed "preview only" and report history is empty by design rather
than populated with invented identifiers.

**The HSE surface is complete (UI-SURFACE-01-HSE).** Fifteen screens across the officer's
shell — overview, active monitoring and its detail, exposure register, review queue, measurement
review, disposition, occupational-health handoff, worker search and profile, exception queue,
badge inventory, batch, calibration and audit. The register carries the full occupational field
set with five filters; the exception queue groups by reason code and filters by workflow state.

**The measurement record is immutable in the UI.** There is no editable field for a dose, an
optical feature or a calibration output anywhere in review — a disposition moves a record
through a workflow and never rewrites what the instrument reported. Disposition states are
workflow only (In review · Additional information required · Reviewed · Closed); there is no
"safe", "medically cleared", "fit for duty" or risk band, and a closing decision requires a
reason. Exceptions carry **no severity banding**: a low/medium/high scale is a clinical or
regulatory classification, and inventing one would let an officer work down the queue as though
the ordering meant something.

Calibration shows every package field and performance metric as **Unavailable** rather than
omitting them — accuracy, LoD, LoQ, RMSE, R², uncertainty, validated range — and documents that
recalibration supersedes for future readings without rewriting history. The audit trail carries
previous → new state, the reason given, source and device, and states that entries are not
signed.

**The Safety surface is complete (UI-SURFACE-01-SAFETY).** All eleven screens are real rather
than shells: a hub that leads with Emergency and H₂S without turning red, a nine-section H₂S
briefing, and honest not-configured states everywhere the organisation must supply content.

Safety copy carries its own provenance model, `SafetyContentSource` — general information,
a DoseBand product statement, an organisation issue, a public standard, demo, or not configured
— rendered in each section's *heading* so a worker reads who is speaking before what is said.
A test asserts nothing DoseBand authors is ever marked as organisational: generated placeholder
text wearing the authority of a site procedure is the failure that model exists to prevent.

Emergency invents nothing. Five configuration slots sit empty, no control appears to place a
call, and a test asserts **no digit sequence appears anywhere on the screen** — a wrong number
there would be dialled in the one situation where being wrong costs the most. The hazard handoff
cannot claim a submission; PPE recommends nothing and never derives equipment from a reading;
SDS entries hold no contents and no invented revision numbers.

**UI-SURFACE-01 is done.** The complete application surface exists across five role registers —
Worker, Safety, HSE, Reporting, Admin — in one MRPL-aligned visual language. 56 routes, every
one resolving; no dead buttons. Worker navigation stays at four destinations (Home · Scan ·
Safety · History) with account behind the header avatar; HSE has its own shell that becomes a
navigation rail at 720 px; Admin and Reporting are sectioned indexes because ten modules do not
fit a bottom bar.

Demo authentication now recognises one deterministic account (published on the sign-in screen
so evaluators never guess), refuses anything else without naming an organisation that was never
queried, and routes each role to its own shell. Forgot-password and Gate Pass open honest
not-connected sheets rather than pretending an email was sent or a pass was read.

**The surface does not hide the science.** No ppm·h figure appears anywhere — no calibration
exists. Every exposure column reads `- - -`. `/hse/calibration` states that no production
calibration exists and lists S1–S3 as OPEN; `/admin/system` carries a standing list of product
limitations; `/admin/integrations` lists all nine integrations as NOT CONNECTED, and there is no
code path that renders "Connected". Demo rows come from one `UiDemoCatalog` and are banner-marked
on every screen that uses them. See `docs/design/screen-catalog.md` and
`docs/design/ui-completion-matrix.md` — the matrix is the map of what looks complete versus what
actually works (27 FUNCTIONAL, 6 PARTIAL, 17 UI ONLY, 9 NOT CONNECTED).

**Phase 2 remaining:** **forward** clock-jump detection — undetectable without a monotonic
platform clock (`SystemClock.elapsedRealtime` / `CLOCK_MONOTONIC`), which needs a platform
channel on both sides and a physical device to verify, so it is an open gap and documented as
one, not a solved problem. Then onboarding, settings, sync/notifications/help/about screens
(Group G). Then Groups H–L (HSE, badge ops, site safety, enterprise, simulation lab).

**Auth flow (AUTH-UI-01) is done:** splash, sign-in, site selection and role selection, wired
`/splash` → `/sign-in` → `/select-site` → `/select-role` → `/workspace/:role`. Demo-only; the
dev skip is gated on `simulationAvailable` so it cannot exist in a production build. Only the
Mangalore Refinery site has a supplied photograph — the other three are painted illustrations,
because a stock photo of some other refinery could be mistaken for a real MRPL location and a
drawing cannot. See `docs/design/auth-flow.md`.

## Architecture

- Dart pub workspace, two packages: `measurement-engine` (pure Dart scientific core, no
  Flutter dependency) + `app` (Flutter). ADR-0004.
- Riverpod 3 state, go_router navigation, Drift/SQLite local store, Supabase backend.
- Deterministic computer vision in pure Dart. No OpenCV, no ML, until measured evidence
  demands it. ADR-0003.
- Offline-first: local SQLite is the source of truth; outbox with client-generated
  idempotency keys pushes to Supabase.
- Result state machine refuses rather than guesses. A failure is never a number.

## Completed

**Phase 0**
- Repository consolidated to a single root; empty `H2S-DoseBand/` skeleton removed.
- Git initialised.
- Flutter upgraded 3.41.2 → 3.47.5 (Dart 3.11 → 3.13). ADR-0007.
- Dart workspace created; Flutter package renamed `app` → `h2s_doseband`.
- Application ID `in.doseband.h2s` with `dev` / `staging` / `prod` flavours and suffixed IDs.
  minSdk 24. Release signing from gitignored `key.properties` with a debug fallback. R8 on.
- Permissions reduced to `CAMERA` and `INTERNET`.
- `EnvironmentConfig`: simulation and experimental features are unavailable in `prod` by
  construction, not by a runtime flag.
- CI: format, analyze, test, build on every PR. Database job stubbed for Phase 7.
- 17 documents under `docs/`, 8 ADRs.

**Verified, not assumed**

| Check | Result |
|---|---|
| `measurement` analyze / test | clean · 12/12 |
| `app` analyze / test / format | clean · 3/3 · clean |
| Android `dev` debug APK | builds; manifest confirms `in.doseband.h2s.dev`, minSdk 24, CAMERA+INTERNET only |
| Android `prod` release APK | builds; R8 and resource shrinking active; keystore fallback evaluates |
| Visual inspection | 26 goldens rendered and reviewed: valid, valid-with-caveat, above range, below LoQ, two refusals, long-label stress, simulated and offline markers, all four shell destinations — each in light and dark, plus small screen and 200% text |

**Phase 1**
- Design tokens: neutral step-wedge surfaces, instrument cyan, status semantics, typography,
  spacing, radii, borders, motion — light and dark, as two `ThemeExtension`s. Widgets read
  semantic tokens only; a literal colour in a widget is a review-blocking change.
- IBM Plex Sans + Mono bundled as assets (809 KB). No `google_fonts`: the app must complete a
  reading offline, so a runtime font fetch is not acceptable.
- Components: buttons (primary / secondary / destructive), status header, measurement readout
  with the empty-slot state, the measurement scale, simulation and offline markers, surfaces,
  traceability rows, reason panel, result card.
- Worker shell on go_router `StatefulShellRoute`: Home · Scan · History · Profile.
- Development-only design system gallery, reachable only where simulation is available, so it
  cannot appear in a production build. Guarded by a test.
- 51 app tests, 12 measurement tests. 26 golden images covering both themes, small screen and
  200% text scale.

**Pulled forward from Phase 5** — the `MeasurementResult` sealed union and `ResultStatus`,
with their invariant tests. Only `Valid` carries a dose; `Refused` and `Censored` have no
field for one. This was written early so the repository's central claim is compiler-checked
rather than only asserted in a document, and so CI has something real to run.

## Open blockers

**These do not close because the UI got better.** UI progress is not evidence about chemistry,
about hardware, or about a clock. Each item below is carried forward deliberately.

### Scientific gates — all OPEN

| Gate | Question | Status |
|---|---|---|
| **S1** | Passive uptake — does the badge sample H₂S at a known, reproducible rate? | **OPEN** |
| **S2** | Chemical integration — is the colour change a faithful integral of exposure? | **OPEN** |
| **S3** | Selectivity / interference — what else changes the colour? | **OPEN** |

No dose may be reported in the field until all three close. See `research/gates/`.

### Hardware validation — OPEN

| Item | Status |
|---|---|
| **M0C physical optical validation** — one real smartphone photographing one real printed target through the actual app | **OPEN.** No phone, no printer. macOS webcam and Chrome results are not evidence about smartphone measurement performance. |
| **Start → app kill → relaunch on a physical phone** | **OPEN.** Persistence is covered by real-file-IO tests and a macOS launch; the last mile on hardware has never been exercised. |
| **Forward wall-clock jump detection** | **OPEN.** Undetectable without a monotonic platform clock (`SystemClock.elapsedRealtime` / `CLOCK_MONOTONIC`), which needs a platform channel on both sides and a device to verify. Backwards jumps *are* caught and refuse. **Do not describe this as "clock integrity".** See `docs/design/persistence.md` §4. |

### Everything else

1. **No laboratory data exists.** No calibration coefficients, LoQ, saturation point,
   uncertainty budget, expiry threshold or validated climate envelope. Until a signed
   calibration model exists, no field dose can be produced — by construction, not by policy.
   See `docs/architecture/readiness.md`.
2. **Badge geometry not frozen.** ROI coordinates are versioned data, never code, for exactly
   this reason.
3. **MRPL requirements unconfirmed.** The twelve questions in dossier §3 determine accuracy
   targets and reporting fields. U1–U5, U8 in `docs/requirements/open-questions.md`.
4. **The official problem-statement PDF has not been read by a human.** `PS-H2S.pdf` uses
   CID-encoded fonts and does not extract mechanically. The traceability matrix is built from
   the dossier's transcription and needs confirming against the source.
5. **No Supabase projects exist yet.** Three are needed (dev / staging / prod) before Phase 7.
6. **Toolchain deprecation pending.** Flutter warns that AGP 8.11.1 and Kotlin 2.2.20 support
   will be dropped "soon". The migration was attempted and reverted — Flutter's own migrator
   writes `android.newDsl=false`, so it is not yet ready for AGP 9. ADR-0008 records the
   trigger to revisit.
7. **Disk headroom is thin.** The machine sat at 152 MB free and broke a build. About 13 GB
   of caches were cleared with approval. Android builds will eat into that.
8. **Riverpod is chosen but not yet installed.** ADR-0001 stands; Phase 1 has no state worth
   managing, so adding it now would be ceremony. It arrives with the Phase 2 workflow state
   machine, which is the first thing that genuinely needs it.
9. **Goldens are macOS-rendered** and excluded from the Linux CI job. ADR-0010.

## Next tasks

**Phase 2 — simulation-mode worker workflow.** See the recommended boundary in
`docs/architecture/implementation-plan.md`. In short: the persisted workflow state machine
(assign → verify → activate → run → close → result → history) driven entirely by simulated
data, with interruption recovery, and the full refusal copy for every reason code. No camera,
no backend, no dose inference.

Full sequence in `docs/architecture/implementation-plan.md`.

## Decisions

| ADR | Decision |
|---|---|
| [0001](docs/decisions/0001-state-management-and-navigation.md) | Riverpod for state, go_router for navigation |
| [0002](docs/decisions/0002-local-persistence.md) | Drift/SQLite for local persistence |
| [0003](docs/decisions/0003-deterministic-cv-no-opencv.md) | Pure-Dart deterministic CV, no OpenCV, no ML initially |
| [0004](docs/decisions/0004-repository-layout.md) | Single repo, Dart workspace, two packages |
| [0005](docs/decisions/0005-supabase-backend.md) | Supabase, separate project per environment |
| [0006](docs/decisions/0006-data-domain-separation.md) | Data domain enforced in the schema |
| [0007](docs/decisions/0007-toolchain-version.md) | Upgrade Flutter before Phase 1 |
| [0008](docs/decisions/0008-defer-agp9-migration.md) | Defer the AGP 9 / Gradle 9 migration |
| [0009](docs/decisions/0009-logarithmic-measurement-scale.md) | The measurement scale is logarithmic, and its ticks cull |
| [0010](docs/decisions/0010-goldens-as-visual-review.md) | Goldens are the visual review artefact, excluded from CI |
