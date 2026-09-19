# ADR-0008 — Defer the AGP 9 / Gradle 9 migration

**Status:** Accepted · 2026-09-19

## Context
Flutter 3.47.5 warns that support will "soon" be dropped for our Android Gradle Plugin
(8.11.1, wants ≥9.0.1) and Kotlin (2.2.20, wants ≥2.3.20). By the reasoning of ADR-0007 —
an empty codebase is the cheapest moment for a toolchain change — the bump was attempted:
Gradle 8.14 → 9.7.1, AGP 8.11.1 → 9.4.1, Kotlin 2.2.20 → 2.3.21.

It failed with three script compilation errors:

```
Line 21: android { ... }
  'fun Project.android(configure: Action<BaseAppModuleExtension>)' is deprecated.
  Not used for public extensions when android.newDsl=true, the default in AGP 9.0.

Line 31: kotlinOptions { jvmTarget = ... }
  deprecated, migrate to the compilerOptions DSL
```

The `kotlinOptions` → `compilerOptions` change is trivial. The first error is not: AGP 9
defaults to a new DSL, and **Flutter's own project migrator writes
`android.newDsl=false` into `gradle.properties`**. Flutter's Gradle plugin is not ready for
AGP 9's DSL, so adopting it means working against the framework's own tooling on the exact
surface — the build — where we can least afford surprises.

## Decision
Stay on Gradle 8.14, AGP 8.11.1, Kotlin 2.2.20. Revisit when a Flutter stable release stops
writing `android.newDsl=false`, which is the signal that Flutter supports AGP 9.

## Why this is safe for now
The warning says support will be dropped "soon", not that it has been. Both a debug and a
release build succeed on the current toolchain, verified. The risk of being caught out is a
future Flutter upgrade requiring this migration under time pressure — which is a real cost,
but a smaller one than destabilising the build now against framework tooling that will
change underneath us anyway.

## Trigger to revisit
A Flutter stable whose migrator no longer sets `android.newDsl=false`. Check at each Flutter
upgrade. When it happens the migration is: remove that property, and replace
`kotlinOptions { jvmTarget = ... }` with `compilerOptions { jvmTarget.set(JvmTarget.JVM_17) }`.
