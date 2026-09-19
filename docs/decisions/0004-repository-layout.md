# ADR-0004 — One repository, Dart pub workspace, two packages

**Status:** Proposed · 2026-09-19

## Context
Directive §36 warns against enterprise ceremony and hundreds of tiny files; §14 requires that
colour-to-ppm·h logic never live in UI code.

## Decision
A single repository containing a Dart pub workspace with exactly two packages:
`packages/measurement` (pure Dart) and `app` (Flutter). Plus `supabase/`, `docs/`, `tools/`.

## Why two, and only two
The boundary is load-bearing rather than decorative: `measurement` has no Flutter dependency,
so it is a compile error to compute a dose inside a widget. That turns directive §14's rule
from a convention into a constraint. It also lets the scientific suite run under `dart test`,
headless and fast, in CI without a Flutter toolchain.

Every other candidate split — separate design-system, networking or database packages —
was rejected. They would be boundaries that buy nothing and cost import churn.

## Alternative considered
A single Flutter package with `lib/measurement/` and a lint rule forbidding Flutter imports
there. Cheaper to set up; weaker enforcement; slower tests. Recommended as the fallback if the
team prefers not to manage a workspace.

## Consequences
- Requires Dart ≥3.6 for pub workspaces. Satisfied.
- `H2S-DoseBand/` (empty skeleton) is folded into the root and removed; `app/` is renamed from
  the `flutter create` default and its application ID changed off `com.example.app`.
