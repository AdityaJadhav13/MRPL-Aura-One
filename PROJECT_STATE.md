# PROJECT_STATE

**Product:** H₂S DoseBand — passive colorimetric cumulative H₂S exposure badge + phone reader
**Programme:** SIH 2026 / PS 26118 (MRPL) · Idea deadline 30 Sep 2026
**Updated:** 2026-09-19

## Current phase

**Phase 1 complete. Phase 2 not started.** Design system implemented, worker navigation
shell built, all four destinations placeheld. The app has no measurement capability, no
backend, no camera, and makes no claim about chemistry.

## Architecture

- Dart pub workspace, two packages: `packages/measurement` (pure Dart scientific core, no
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
