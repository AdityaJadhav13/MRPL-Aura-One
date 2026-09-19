# ADR-0002 — Drift (SQLite) for local persistence

**Status:** Proposed · 2026-09-19

## Context
Local storage is the offline source of truth (directive §16) and the place where the "a
failure is never a number" rule is enforced structurally (directive §5, §18).

## Decision
Drift over SQLite.

## Why
- **CHECK constraints.** The `dose_only_when_valid` constraint is the single most important
  correctness mechanism in the data layer. It needs a real SQL engine.
- **Tested migrations.** Drift ships a migration test harness. Directive §26 requires
  migration tests; with raw `sqflite` we would build that harness ourselves.
- **Transactions.** Every workflow transition writes state and an outbox row atomically.
- **Type-safe queries** for the officer's exception views, which are genuinely relational.

Rejected: `sqflite` raw (we would rebuild Drift badly), Hive/Isar (no constraints, and Isar is
effectively unmaintained), `shared_preferences` for anything beyond UI preferences.

## Consequences
- `build_runner` is in the toolchain. Accepted; it earns its place here.
- The local schema must be kept deliberately in step with the Postgres schema. Both are
  hand-written; a single generator producing both was considered and rejected as premature.
