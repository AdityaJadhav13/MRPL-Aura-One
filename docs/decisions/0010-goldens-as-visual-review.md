# ADR-0010 — Golden images are the visual review artefact, and are excluded from CI

**Status:** Accepted · 2026-09-19

## Context
Directive §39 requires a visual review of every major screen, and Phase 1 asked
for the implemented screens to be inspected rather than treated as done because
they compiled. That needs rendered images, not a passing test count.

## Decision
Golden tests generate PNGs for every important state, in both themes, at small
screen size and at 200% text scale. They serve two purposes at once: the
regression guard, and the artefact a reviewer actually looks at.

The specimens are defined once in `lib/features/gallery/gallery_specimens.dart`
and shared between the on-device gallery and the goldens, so what a reviewer sees
on a phone and what CI guards cannot drift apart.

Goldens are tagged `golden` and **excluded from the Linux CI job**.

## Why exclude them from CI
Goldens are rasterised by the host platform. A macOS-generated image does not
match a Linux runner byte-for-byte — different font rasterisation, not different
layout. Running them in CI produces failures that carry no information and train
the team to ignore red builds.

They remain valuable as a same-platform guard: a developer on macOS sees a real
diff when a component changes.

## What this cost, and what it bought
Bought: three real defects caught before any of this reached a device.

1. Two em dashes at 60px tiled into one solid bar that read as a redaction, not
   an empty slot. Changed to separated dashes, which is also what a balance or a
   multimeter shows when it has no value.
2. The reason panel rendered at true black in dark mode, violating the design
   system's rule that true black is viewfinder-only. A token bug, now guarded by
   a test.
3. At 200% text scale, the traceability label column broke words mid-syllable,
   and the scale's tick labels did not scale at all — text painted inside a
   `CustomPainter` does not inherit `MediaQuery` scaling. Both compiled and
   passed every test that existed at the time.

None of these would have been found by reading the code.

## Revisit when
If golden diffs become a routine chore, or if a macOS CI runner becomes
available, re-enable them in CI on that runner only.
