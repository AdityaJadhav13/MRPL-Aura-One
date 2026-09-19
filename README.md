# H₂S DoseBand

Phone reader for a passive colorimetric cumulative hydrogen sulfide exposure badge.
SIH 2026 · Problem statement 26118 · MRPL.

> **Status: Phase 0.** Architecture and repository foundation only. The app has no
> measurement capability, and the chemistry it would read does not yet exist. Nothing here
> claims accuracy, shelf life or certification.

## What this is

A worker wears a disposable badge for a shift. The badge's chemistry changes colour in
proportion to accumulated H₂S. At the end of the shift a phone photographs it, and the app
estimates the external exposure in ppm·h — **or refuses, and says why**.

The refusal is the product. A confident number derived from a scan that did not support it
would land on a worker's health record and be believed. That is the highest-severity failure
this system can produce, and the architecture is arranged to make it hard to reach:

- `packages/measurement` has no Flutter dependency, so a dose cannot be computed in a widget.
- `MeasurementResult` is a sealed union in which only the valid states have a dose field.
- A database CHECK constraint makes a non-valid result with a dose unrepresentable.
- Reference patches are split: some fit the colour correction, others are withheld to test it.
- Without a signed, validated calibration model, no field dose can be produced at all.

## What this is not

It does not diagnose disease, determine whether a worker is medically safe, or replace
certified real-time H₂S alarms. It measures external concentration integrated over time. A low
shift average cannot rule out a dangerous short peak.

## Layout

```
app/                    Flutter application
packages/measurement/   Pure Dart scientific core — CV, colour, calibration, validity
supabase/               Migrations, RLS policies, pgTAP tests
tools/                  Calibration ingestion, fixture generation
docs/                   Architecture, decisions, requirements, CV specification
```

## Start here

| Document | |
|---|---|
| [PROJECT_STATE.md](PROJECT_STATE.md) | Current phase, blockers, next tasks |
| [docs/architecture/overview.md](docs/architecture/overview.md) | The whole design |
| [docs/architecture/readiness.md](docs/architecture/readiness.md) | What can be built now vs. what waits for the lab |
| [docs/requirements/open-questions.md](docs/requirements/open-questions.md) | Contradictions and unknowns |
| [docs/decisions/](docs/decisions/) | ADRs |

## Building

```bash
flutter pub get
flutter run --flavor dev -t lib/main_dev.dart \
  --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

```bash
dart test                        # from packages/measurement — headless, fast
flutter test                     # from app
```

Three flavours — `dev`, `staging`, `prod` — with separate application IDs and separate
Supabase projects. Simulation mode is unavailable in `prod` by construction.
