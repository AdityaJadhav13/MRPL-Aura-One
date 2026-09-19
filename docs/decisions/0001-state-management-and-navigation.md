# ADR-0001 — Riverpod for state, go_router for navigation

**Status:** Proposed · 2026-09-19

## Context
Directive §38 requires one state-management approach, chosen and justified. The app's state is
dominated by asynchronous, cacheable, invalidatable resources: calibration models keyed by lot,
sync queue state, the persisted workflow state machine, and a camera frame stream.

## Decision
`flutter_riverpod` for state. `go_router` for navigation.

## Why Riverpod
- `AsyncValue` is exactly the loading/error/data triad this app needs on nearly every screen,
  and it forces the error case to be handled rather than forgotten. Given that this app's
  error states are the product, that alignment matters more than usual.
- Provider invalidation maps cleanly onto "calibration model changed, recompute what depends
  on it".
- `ProviderContainer` with overrides lets the whole scientific path be driven from a test
  without building a widget tree.
- It is a dependency-injection container as well, so no second DI package is needed.

Bloc was the main alternative. It is a reasonable choice, but it adds an event class per
interaction across ~25 screens for no benefit this app can point at. Rejected on ceremony.

## Why go_router
Role-based shells (worker / officer / admin) with redirect guards on auth and role. This is
fiddly and error-prone with imperative `Navigator`, and it is the entire justification —
deep links are not a requirement today.

## Consequences
- One state solution. Mixing in another is a review-blocking change.
- Riverpod 3.4.3 requires Dart ≥3.12; on the currently installed Dart 3.11 it resolves to
  3.3.2. See ADR-0007.
- Code generation (`riverpod_generator`) is **not** adopted initially. Manual providers are
  fine at this scale and one less build step. Revisit if provider boilerplate becomes real.
