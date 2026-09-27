# ADR-0003 — Hand-written deterministic CV in pure Dart; no OpenCV, no ML initially

**Status:** Proposed · 2026-09-19

## Context
The pipeline needs: blur/exposure metrics, fiducial detection, homography, perspective warp,
ROI sampling, least-squares colour fitting, CIELAB and ΔE₀₀. The obvious move is `opencv_dart`
(2.2.2 on pub.dev). The dossier is explicit that deterministic methods should come first and
that ML cannot recover information the sensor did not capture.

## Decision
Implement the pipeline in pure Dart in `measurement-engine`, using `image` for decode only.
No OpenCV. No ML model.

## Why
- **We control the badge.** Fiducials are ours to design, so detection is a bounded geometry
  problem — adaptive threshold, connected components, centroid — not open-world detection.
  OpenCV's value is robustness against problems we have designed away.
- **Cost.** `opencv_dart` adds tens of megabytes of native libraries per ABI and an FFI
  boundary, for perhaps 400 lines of well-understood linear algebra.
- **Testability.** Pure Dart runs headless under `dart test` in milliseconds. The scientific
  core's test suite is the project's most important asset and it should not need a device, a
  native toolchain or a platform channel.
- **Auditability.** Every numerical step in a measurement pipeline should be readable by the
  person defending the measurement. A DLT implementation we wrote is inspectable; a call into
  a native library is not, in the same way.

## When to revisit
Concrete, measurable triggers — not taste:
1. Fiducial detection fails on >2% of otherwise-good captures in device-matrix testing.
2. Pipeline latency exceeds 2 s on the low-end reference device.
3. Field data shows a badge-localisation failure mode that geometry cannot solve.

ML is admitted only for ROI localisation or contamination rejection, only after it beats the
deterministic baseline on held-out specimens from an unseen lot and unseen phones, and never
as the dose estimator without that same evidence. An LLM has no role in dose inference.

## Consequences
- We own ~400 lines of linear algebra and colour maths. They are the best-tested lines in the
  repository.
- The pipeline is a set of pure functions, not an interface with one implementation. If
  OpenCV is later needed for one stage, that stage's function is swapped; no abstraction is
  built in advance for a swap that may never happen.
