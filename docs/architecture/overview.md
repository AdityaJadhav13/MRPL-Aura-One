# Architecture overview

## Design premise

This application is the readout half of a measuring instrument. Its job is not to display
data; its job is to decide whether a number may honestly be produced, and to refuse when it
may not. Every architectural choice below is subordinate to that.

The highest-severity failure mode is **false reassurance** — a confident ppm·h value derived
from a scan that did not actually support it. The architecture is arranged so that producing
such a value requires defeating several independent mechanisms, not just one bug.

## Repository structure

```
/                                 git root (to be initialised)
├── PROJECT_STATE.md
├── pubspec.yaml                  Dart pub workspace root
├── docs/
│   ├── requirements/             traceability, open questions
│   ├── architecture/             this set
│   ├── decisions/                ADRs
│   ├── computer-vision/          pipeline + colour science
│   ├── design/                   design system spec, screen specs
│   └── backend/                  Supabase schema notes, RLS matrix
├── packages/
│   └── measurement/              pure Dart. No Flutter import, ever.
│       ├── lib/src/imaging/      quality, fiducials, homography, rectify, ROI
│       ├── lib/src/colour/       linearisation, correction fit, CIELAB, ΔE2000
│       ├── lib/src/features/     ROI statistics, spatial features
│       ├── lib/src/calibration/  model types, interpolation, uncertainty
│       ├── lib/src/validity/     validity engine, result state machine
│       └── test/fixtures/        deterministic images + expected outputs
├── app/                          Flutter application
│   ├── lib/core/                 design system, theme, routing, errors, logging
│   ├── lib/data/                 Drift database, Supabase client, sync outbox
│   ├── lib/domain/               entities, repositories
│   ├── lib/features/<feature>/   screens + controllers, one directory per feature
│   └── test/ · integration_test/
├── supabase/
│   ├── migrations/               SQL, forward-only, numbered
│   ├── tests/                    pgTAP RLS and constraint tests
│   └── functions/                edge functions
└── tools/                        calibration ingestion CLI, fixture generation
```

Two packages, not fifteen. The single boundary that exists is load-bearing: `measurement`
cannot import Flutter, so a colour value can never be turned into ppm·h inside a widget. The
directive's §14 rule is enforced by the compiler rather than by review.

`tools/` is a plain Dart CLI, not a package, and exists because calibration ingestion must be
reproducible and scriptable — a lab engineer running a command, not a developer editing
Dart literals.

## Technology choices

| Concern | Choice | Reason | ADR |
|---|---|---|---|
| State | Riverpod 3 | The app is mostly async, cached, invalidatable state (calibration, sync, camera). `AsyncValue` maps exactly onto the loading/error/data triad this app needs everywhere, and `ProviderContainer` overrides make the scientific path testable without a widget tree. | 0001 |
| Navigation | go_router | Role-based redirect guards (worker vs officer vs admin shells) are genuinely awkward with imperative `Navigator`; that is the whole justification. | 0001 |
| Local store | Drift (SQLite) | We need transactions, CHECK constraints, and *tested* migrations. Drift gives schema-versioned migrations with a migration test harness. Raw `sqflite` means hand-writing all of it. | 0002 |
| Backend | Supabase | Postgres + RLS + Auth + Storage covers organisation isolation, role enforcement and evidence-image storage without writing a server. Realtime is **not** used. | 0005 |
| Camera | `camera` | First-party. Gives the frame stream the guidance overlay needs. | — |
| QR | `mobile_scanner` | Wraps MLKit/AVFoundation. Writing this ourselves is not defensible. | — |
| Image decode | `image` | Pure Dart, isolate-safe, gives raw pixel access. | 0003 |
| Computer vision | Hand-written pure Dart | See ADR-0003. No OpenCV until measurement evidence demands it. | 0003 |
| Secure storage | `flutter_secure_storage` | Keychain / Android Keystore for the session token. | — |
| Crash / logs | Sentry, added at Phase 12 | Not before there is something worth observing. | — |

Deliberately **not** used: any dependency-injection framework (Riverpod is one), any
code-generation-heavy architecture template, `freezed` for every model (used only where sealed
unions genuinely pay — the result state), realtime subscriptions, background location,
analytics SDKs.

## The measurement core

`packages/measurement` is a pipeline of pure functions. No I/O, no clock, no randomness
unless injected. Everything is deterministic and fixture-testable.

```
CapturedFrame
  → FrameQuality          blur, exposure, clipping, glare
  → FiducialSet           four corner markers located
  → Homography            DLT, normalised
  → CanonicalBadge        rectified into badge millimetre space
  → PatchSamples          reference patches read at geometry-defined coords
  → ColourCorrection      fitted on a subset of patches
  → CorrectionResidual    measured on the HELD-OUT patches  ← the honesty check
  → RoiFeatures           active / blank / expiry, robust statistics in CIELAB
  → CalibrationModel      loaded by lot, versioned, checksummed
  → MeasurementResult     status + optional dose + uncertainty + reasons
```

Three properties are non-negotiable:

1. **Held-out patch validation.** Some reference patches fit the colour correction; others
   are withheld and used only to test it. If ΔE₀₀ on the held-out set exceeds the profile's
   threshold, the scan is rejected. This is the mechanism that stops a plausible-looking but
   wrong colour transform producing a plausible-looking but wrong dose.
2. **Fail-closed.** Any missing input — no calibration model, unknown lot, absent geometry
   version, unreadable blank — produces a refusal, never a default. There is no code path
   where absence of information yields a number.
3. **Structural impossibility of "0 ppm·h on failure."** `MeasurementResult` is a sealed
   union where only `Valid` and `ValidWithWarning` carry a dose. The other states have no
   dose field to populate. Mirrored in the database by a CHECK constraint.

Detail in `docs/computer-vision/pipeline.md`.

## Result contract

```dart
sealed class MeasurementResult {
  MeasurementStatus get status;
  List<ReasonCode> get reasons;        // never empty for non-valid states
  QualityMetrics get quality;
  Provenance get provenance;           // model, algorithm, app, device, geometry versions
}

final class Valid extends MeasurementResult {
  final Quantity dose;                 // ppm·h
  final Uncertainty uncertainty;       // with a stated, evidenced coverage
  final Duration coverage;
}
final class ValidWithWarning extends Valid { }
final class Censored extends MeasurementResult {
  final CensorDirection direction;     // below LoQ / above range
  final Quantity? bound;               // defensible one-sided bound where one exists
}
final class Refused extends MeasurementResult { }  // every other status
```

`Censored` exists because the dossier is explicit on two points: below the LoQ the app must
state "below validated LoQ" and never an exact zero; above range it must state "above range"
while retaining a defensible lower bound. Those are not errors and not valid numbers — they
are a third thing, and collapsing them into either would misreport.

Every state's user-facing copy answers three questions, per directive §30: what happened, why
it matters, what to do next. Reason codes map to that copy in one table, so the message is
never assembled ad hoc at the call site.

## Validity engine

A list of independent checks, each a pure function returning pass / warn / fail with a reason
code. The engine runs all of them — it does not short-circuit, because the user deserves every
reason, not the first one. Severity then resolves the final status: any hard fail refuses;
otherwise warnings downgrade valid to valid-with-warning.

Check families: badge state (expired, already used, damaged, unsupported batch), image quality
(blur, glare, clipping, resolution, geometry), colour correction (residual on held-out
patches), chemistry consistency (blank vs sensor disagreement, contamination signature),
domain support (calibration present, lot supported, environment inside validated envelope),
and coverage (partial shift, missing start, read-by window exceeded, clock anomaly).

## Core workflow and interruption recovery

The workflow is a persisted state machine, not a navigation stack. Every transition is written
to SQLite in a transaction before the UI advances. Killing the app mid-shift loses nothing
because there is no in-memory-only state to lose.

| Interruption | Behaviour |
|---|---|
| App killed mid-shift | On launch, the active `exposure_session` is read from disk and the app resumes at the correct step. |
| Phone restarted | Same. Start time is a stored timestamp, not a running timer. |
| No network | Entire workflow completes offline provided the lot's calibration model is already cached. |
| Worker changes device | Shift is owned by the server record; the new device pulls it on sync. Until sync, the new device shows the shift as claimed elsewhere rather than starting a second one. |
| QR damaged | Manual badge-ID entry with the check character; the entry path is marked in provenance. |
| Camera unavailable | Workflow halts at scan with an explicit state. Shift data is intact; the badge can be read later within the read-by window. |
| Scan fails | Retake, with the specific reason. Failed scans are stored, not discarded — a pattern of failures is diagnostic. |
| Badge expired / unsupported lot | Refusal before capture, so the worker is not asked to do pointless work. |
| Shift ended early | `PARTIAL_SHIFT`. The dose is whatever was integrated; it is never extrapolated to a full shift, and never normalised to an 8-hour TWA. |

**Clock integrity.** Exposure duration derives from the device clock, which a user can change.
At session start the app records the wall clock, the monotonic elapsed-realtime counter, and
(if online) server time. At close it compares them. Divergence beyond tolerance raises a
coverage warning rather than being silently accepted.

## Offline-first and synchronisation

Local SQLite is the source of truth. The app never waits on the network to complete a
worker-facing action.

Writes go to the local tables and an `outbox` row in the same transaction. A background
sender drains the outbox with exponential backoff. Each mutation carries a client-generated
UUIDv7 as its idempotency key; the server upserts on that key, so replaying the queue — after
a crash, a timeout that actually succeeded, or a double-tap — is harmless.

Conflicts are largely designed away rather than resolved: scans, features and results are
**immutable and append-only**. The only mutable rows are assignment status and review status,
both of which are server-authoritative and last-writer-wins with an audit entry. A
recalculated result is a *new* row pointing at the old one via `supersedes_result_id`; the
original is never modified.

Calibration models flow the other way — pulled and cached locally with their checksum
verified before use. A device with no cached model for a badge's lot cannot produce a dose,
and says so.

## Security model

- **Authentication** via Supabase Auth. Session token in Keychain / Android Keystore, never
  in shared preferences. Short-lived access token, refresh on the server.
- **Authorisation on the server.** RLS policies on every table, keyed on `org_id` and role
  claims in the JWT. The client's role checks exist to shape the UI; they are never the
  enforcement point.
- **Organisation isolation** from day one: `org_id` is NOT NULL on every tenant table and
  every policy filters on it.
- **Identity separation** (C4 above): exposure rows carry `worker_token`; the token → person
  mapping is a separate table with a stricter policy. A safety officer reviewing an exception
  sees a token and a department unless their role grants identification.
- **No admin secrets in the client.** Service-role keys exist only in edge functions. The
  anon key is the only key shipped, and it is useless without a session.
- **Evidence images** go to a private Storage bucket, accessed only through short-lived signed
  URLs. They are never public.
- **Audit** is append-only: issuance, scanning, review, correction, supersession, export, and
  role change all write an immutable `audit_events` row.
- **Rate limiting** on auth and on scan upload, at the edge.

## QR payload

Compact, versioned, opaque. It identifies the badge and nothing else.

```
H2S1:<badge_id_base32>:<lot_code>:<check>
```

`v1` schema tag, a badge identifier, a lot code to allow offline lot-status checks without a
round trip, and a check character to catch misreads. **No worker identity, no medical
information, no calibration data.** Calibration is retrieved from cached trusted data keyed by
lot, never carried on the badge — a QR code is user-modifiable input and must never be a
source of measurement parameters.

## Navigation

Role-shaped, not a shared template with hidden tabs.

**Worker** — a four-item bar, because a worker on a plant floor wearing gloves needs the
next action to be obvious: `Home` · `Scan` · `History` · `Profile`. "Current shift" is not a
tab; it is what Home *is* when a shift is active.

**Safety officer** — `Exceptions` · `Workers` · `Badges` · `Reports`. Exceptions is the
landing screen. The officer's question is never "how are things overall", it is "what needs
me right now".

**Administrator** — a settings-shaped list rather than a tab bar: organisation, users and
roles, calibration models, devices, audit log. Low-frequency, high-consequence tasks.

Role is resolved after authentication and selects the shell. A user holding several roles gets
a switcher; the app never merges two roles' navigation into one crowded bar.

## Screen inventory

**Worker (13)** — Sign in · Home (idle) · Home (shift active) · Scan QR · Badge verification ·
Activation guide · Shift in progress · End shift & closure guide · Guided camera scan ·
Processing · Result (valid / censored / refused variants) · History list · History detail ·
Profile & sync status.

**Safety officer (6)** — Exceptions queue · Worker roster · Worker exposure history · Badge
inventory & lot status · Scan review detail with evidence image · Reports & export.

**Administrator (5)** — Organisation structure · Users & roles · Calibration model management ·
Device registry · Audit log.

**Development (1)** — Simulation console: choose a synthetic badge state (blank, low, mid,
high, saturated, expired, damaged, glare, bad perspective) and run it through the real
pipeline. Debug builds only.

Twenty-five screens. Each gets the eight-point quality gate of directive §39 before its
feature is called complete.

## Worker home

Home answers, in this order, without scrolling:

1. Am I on a monitored shift? (state, not a metric)
2. Which badge, and is it valid?
3. How long has it been active, and what is the coverage?
4. What do I do next? (one primary action, always)
5. Is my data synced?

No charts. No dashboard tiles. A worker opens this app perhaps three times a shift and needs
an answer each time, not an overview.

## Delivery

Three flavours — `dev`, `staging`, `prod` — with separate application IDs, separate Supabase
projects and separate signing. Simulation mode is compiled out of `prod`. Production
credentials never reach a development build.

CI on every pull request: `dart format --set-exit-if-changed`, `flutter analyze --fatal-infos`,
`dart test` on `packages/measurement`, `flutter test`, golden tests, pgTAP against a
throwaway Postgres, then `flutter build appbundle`.

Android permissions: `CAMERA` and `INTERNET`. Nothing else. No location, no storage, no
microphone, no contacts.

Feature flags: `simulation_mode`, `experimental_cv`, `experimental_calibration`,
`safety_dashboard`, `environmental_compensation`. Experimental flags default off in `prod` and
cannot be enabled from the client UI.

## Gate

Before Phase 1 begins, five decisions need the team, not the architect:

1. Fold `H2S-DoseBand/` into the repository root and delete the empty skeleton? (C1)
2. Upgrade Flutter 3.41.2 → 3.47.5 now? (C6)
3. `git init` and first commit — confirm this should happen.
4. Two-package Dart workspace, or a single Flutter package with a `lib/measurement/`
   directory? The workspace is recommended; the single package is the cheaper answer if the
   team would rather not manage a workspace.
5. Android-only validation target, or iOS too? (U6)
