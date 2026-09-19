# PROJECT_STATE

**Product:** H₂S DoseBand — passive colorimetric cumulative H₂S exposure badge + phone reader
**Programme:** SIH 2026 / PS 26118 (MRPL) · Idea deadline 30 Sep 2026
**Updated:** 2026-09-19

## Current phase

**Phase 0 complete. Phase 1 not started.** Repository inspected, requirements traced,
architecture documented and approved at the gate, foundation built. The app has no
measurement capability and makes no claim about chemistry.

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
- 15 documents under `docs/`, 7 ADRs.

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

## Next tasks

**Phase 1 — design system and navigation shell.** Semantic tokens, light and dark, the
measurement numeral style, core components (status chip, reason panel, measurement readout,
simulation banner), role shells and go_router guards. Golden tests from the first component.

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
