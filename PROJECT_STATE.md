# PROJECT_STATE

**Product:** H₂S DoseBand — passive colorimetric cumulative H₂S exposure badge + phone reader
**Programme:** SIH 2026 / PS 26118 (MRPL) · Idea deadline 30 Sep 2026
**Updated:** 2026-09-19

## Current phase

**Phase 0 — architecture gate.** Repository inspected, requirements traced, architecture
proposed. Awaiting approval before Phase 1 implementation. No product code written yet.

## What exists

| Path | State |
|---|---|
| `app/` | Stock `flutter create` counter app, package name `app`, appId `com.example.app` |
| `H2S-DoseBand/` | Empty directory skeleton + 63-byte README. No content. |
| `docs/` | This architecture set (new) |
| git | **Not initialised.** No version control on the project. |

## Architecture (proposed, not yet approved)

- Dart pub workspace, two packages: `packages/measurement` (pure Dart scientific core) + `app` (Flutter).
- Riverpod 3 state, go_router navigation, Drift/SQLite local store, Supabase backend.
- Deterministic computer vision in pure Dart. No OpenCV, no ML, until measurement evidence demands it.
- Offline-first: local SQLite is the source of truth; outbox queue with client-generated
  idempotency keys pushes to Supabase.
- Result state machine refuses rather than guesses. A failure is never a number.

## Completed features

None. Phase 0 only.

## Open blockers

1. **Architecture gate not yet approved** — see `docs/architecture/overview.md` §Gate.
2. **No laboratory data exists.** No calibration coefficients, LoQ, saturation point,
   uncertainty budget, expiry threshold or validated climate envelope. See
   `docs/architecture/readiness.md`.
3. **Badge geometry not frozen.** ROI coordinates are versioned data, not code, precisely
   because of this.
4. **MRPL requirements unconfirmed.** Twelve questions in dossier §3 remain unanswered;
   they determine accuracy targets and reporting fields.
5. **Toolchain is behind.** Installed Flutter 3.41.2 / Dart 3.11.0; current stable is
   3.47.5 / Dart 3.13.4. Latest riverpod, go_router and camera require Dart ≥3.12.

## Next tasks

See `docs/architecture/implementation-plan.md`.

## Important decisions

ADRs live in `docs/decisions/`. Index:

| ADR | Decision |
|---|---|
| 0001 | Riverpod for state management |
| 0002 | Drift/SQLite for local persistence |
| 0003 | Pure-Dart deterministic CV, no OpenCV initially |
| 0004 | Single repo, Dart workspace, two packages |
| 0005 | Supabase backend with per-environment projects |
| 0006 | Data domain (simulated / lab / field) enforced in the schema |
| 0007 | Upgrade Flutter 3.41.2 → 3.47.5 before Phase 1 |
