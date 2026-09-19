# ADR-0007 — Upgrade Flutter before Phase 1

**Status:** Proposed, needs team decision · 2026-09-19

## Context
Installed: Flutter 3.41.2, Dart 3.11.0 (released 2026-02-18). Current stable: Flutter 3.47.5,
Dart 3.13.4.

Latest versions of three packages we intend to use require Dart ≥3.12 and would resolve
downward on the current SDK:

| Package | Latest | Resolves to on Dart 3.11 |
|---|---|---|
| `riverpod` / `flutter_riverpod` | 3.4.3 | 3.3.2 |
| `go_router` | 18.0.1 | 17.5.0 |
| `camera` | 0.12.1 | 0.12.0+2 |

`drift` 2.35.0, `mobile_scanner` 7.4.2 and `supabase_flutter` 2.17.2 are unaffected.

## Decision
Upgrade to Flutter 3.47.5 before writing product code.

## Why now
The repository contains one stock `flutter create` app and no product code. This is the
cheapest moment this upgrade will ever be. Deferring it means a migration across ~25 screens
later, most likely under submission pressure.

## Risks
Two Flutter minors' worth of behaviour and deprecation changes, absorbed against a codebase
with nothing in it. The Android toolchain (AGP, Kotlin, Gradle) may need bumping alongside.

## Alternative
Pin to the resolvable versions above and stay on 3.41.2. Workable — none of the downgrades
lose a feature we depend on — but it accumulates a debt with no offsetting benefit.
