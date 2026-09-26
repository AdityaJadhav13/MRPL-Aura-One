# Fiducial benchmark

**Status:** provisional. Synthetic evidence only.
**Decision:** the custom DoseBand detector is the **incumbent on probation**. It is not selected.
**Blocking evidence:** dossier V0 photographs (`research/dossier-v0.md`).

---

## 1. The rule this document exists to enforce

> Do not select the custom implementation merely because we wrote it.

A detector we own is easier to reason about and has no native dependency
(ADR-0003). Neither of those is a detection rate. This document keeps the
question open until there is one.

## 2. Candidates

| | Approach | Status here |
|---|---|---|
| **A** | **ArUco** (OpenCV `cv2.aruco`) — binary-coded square markers, identity and orientation carried in the marker | **Not benchmarked.** See §5. |
| **B** | **AprilTag** — coded square markers with stronger error correction and sub-pixel edge refinement | **Not benchmarked.** See §5. |
| **C** | **Custom DoseBand detector** — Bradley adaptive threshold → connected components → shape filtering → intensity-weighted sub-pixel centroid → geometric identification → cross-check against withheld markers | **Benchmarked below.** |

## 3. What was actually measured

`packages/measurement/tool/fiducial_benchmark.dart`, run on rendered
`badge-v1-research` fixtures. Every distortion is synthetic. **These numbers
describe the detector on rendered images and say nothing about photographs.**

"Worst centroid error" is the largest distance, over all four corners and all
cases in the row, between the detected centroid and the true projected marker
centre.

| Condition | Cases | Found | Worst centroid err (px) | Median ms |
|---|---|---|---|---|
| nominal (10–16 px/mm) | 4 | 100% | 0.00 | 26 |
| rotation 0 to 90° | 13 | 100% | 0.35 | 16 |
| perspective / tilt | 5 | 100% | 0.35 | 15 |
| scale 8 to 20 px/mm | 7 | 100% | 0.00 | 24 |
| defocus (box blur r=1..4) | 4 | 100% | 0.35 | 16 |
| uneven illumination (to 20% at one edge) | 5 | 100% | 0.03 | 14 |
| glare over the badge | 4 | 100% | 0.00 | 15 |
| **one corner occluded** | 4 | **0%** | n/a | 57 |
| print degradation (fade 20–80%) | 4 | 100% | 6.30 | 14 |
| dark to light background | 4 | 100% | 0.00 | 17 |
| warm / cool illuminant | 3 | 100% | 0.00 | 15 |

**0% on the occlusion row is the correct result.** It means refusal. See §4.1.

A permanent adversarial suite extends this row into sixteen cases —
`packages/measurement/test/geometry/adversarial_pose_test.dart`. It asserts a
one-sided property, *refuse or be right*, and never requires detection to
succeed. Current result: **0 confident wrong poses out of 16.**

Latency is 14–26 ms per frame on an M-series Mac in the Dart VM. That is a
**loose upper bound at best** for a mid-range Android phone, and the sweep
includes multiple threshold passes on failure (the 63 ms occlusion row). It is
recorded as an order of magnitude, not a specification.

## 4. What benchmarking found that reasoning had not

Three defects, all found by measurement, all now fixed and regression-tested.

### 4.1 The detector reported confident, wrong poses **[critical]**

The first occlusion run reported **100% detection with a worst centroid error
of 528 px**. With one corner covered, the largest-quadrilateral search promoted
some other blob and returned a pose that fitted its own four points perfectly.

A wrong pose is far worse than no pose: everything downstream then samples the
wrong part of the badge, the colour correction fits against the wrong patches,
and nothing anywhere says so.

**Fix:** after identifying four corners, the pose is cross-checked against the
secondary markers, which had no say in it. If fewer than 60% of them land where
the pose predicts, detection is refused with
`DetectionRejection.inconsistentWithGeometry`. The occlusion row went from
"100% found, 528 px error" to "0% found", which is the honest answer.

This is the same principle as the held-out colour patches: a model scored on
its own inputs cannot report its own failure.

### 4.2 A fill-ratio threshold above 0.5 silently rejects rotated markers

Detection failed completely between roughly 25° and 65° of rotation while
succeeding at 0°, 17° and 80°. The cause is geometry, not code: a solid square
at angle θ fills `1 / (cosθ + sinθ)²` of its axis-aligned bounding box — 1.0 at
0°, **exactly 0.5 at 45°**. The acceptance threshold was 0.62.

**Fix:** threshold lowered to 0.42, below the floor, with the floor documented
on `Blob.fillRatio` and pinned by a test that renders squares at several angles
and checks the measured ratio against `1/(cosθ+sinθ)²`.

### 4.3 The adaptive-threshold window is pinned between two constraints

Bradley compares each pixel to its local neighbourhood, which is what makes it
survive uneven illumination. But:

- the window must **exceed** the marker, or the marker's interior becomes its
  own background and only a hollow outline survives thresholding;
- the window must be smaller than **twice the badge's quiet zone**, or the dark
  rim that thresholding produces against a dark background reaches inward far
  enough to merge with the corner markers — making the whole badge one
  connected component that the area filter then discards.

Both depend on how large the badge is in frame, which is what detection is
trying to establish.

**Fix, two parts.** A short sweep of window fractions resolves the
circularity at runtime. And badge design rule **R6** gives every printed
feature a quiet zone at least one fiducial width wide.

**This coupling is a property of adaptive-threshold blob detection, not of our
code, and it is the sharpest argument in favour of A or B.** ArUco and AprilTag
do not have it: they look for quadrilateral contours with a decodable interior,
so marker size and window size are not in tension.

### 4.4 A half-covered marker reports a displaced centre **[M0C-1, fixed]**

The adversarial suite found a case the geometry cross-check missed: covering
half a corner marker still yields a blob, and the detector accepted it with the
centroid **14 px from truth** — about 1 mm of badge. The secondary markers
still landed inside their matching tolerance, so §4.1's guard said nothing.

1 mm matters: ROI erosion margins on badge v1 are 0.55–1.0 mm, so that error
can pull a neighbouring reference patch into a sampling window.

**Fix:** each marker's expected area is projected through the pose and compared
with the detected blob; half coverage reads ~50% and is refused. The area is
projected **through the homography**, not derived from a global
pixels-per-millimetre — under perspective a far marker is legitimately smaller,
and a global scale rejected it for being exactly what it should be.

### 4.5 Print degradation is accepted at 6.30 px error **[open]**

At 80% fade toward the substrate the detector still reports success with a
worst centroid error of 6.30 px. Neither guard catches it: the whole badge
fades together, so the error is consistent across markers and the cross-checks
agree with each other.

Not fixed, because the right threshold depends on what a genuinely badly
printed badge looks like — a dossier V0 question. Recorded so it is not
mistaken for a clean result.

## 5. Why A and B are not benchmarked here, and what that costs

Honest statement rather than a gap left implicit.

- OpenCV is **not available in this environment**: no `cv2`, and Python 3.14
  has no `opencv-python` wheel. So `cv2.aruco` could not be run.
- ADR-0003 excludes OpenCV from the *application*. It does **not** exclude it
  from `research/`, and a fair benchmark of A and B belongs there — in Python,
  against the same fixtures, using the same harness contract.
- Running ArUco against *rendered* fixtures would in any case be the weaker
  half of the comparison. The conditions that separate these approaches —
  real print, real optics, real motion blur, real specular behaviour — only
  appear in photographs.

**What this means:** the custom detector has not beaten anything. It has been
shown to work on rendered fixtures after three defects were found and fixed.
That is a starting position, not a selection.

### The comparison to run

Same fixtures, same metrics, one harness, in `research/notebooks/`:

| Axis | Why it discriminates |
|---|---|
| Detection rate | The headline. |
| **False-positive rate** | Promoted to first class by §4.1. A detector that refuses is usable; one that invents a pose is not. Measured by occluding, damaging and removing markers and counting confident wrong answers. |
| Rotation, perspective, scale | Where §4.2 and the window coupling bite. |
| Blur, glare, uneven illumination | Field conditions. |
| **Partial occlusion** | ArUco/AprilTag decode an identity per marker and can drop one cleanly; C must infer identity from arrangement. Expect C to lose here. |
| Print degradation | Cheap printing, worn badges. |
| Latency on the low-end reference device | Not on a Mac. |
| Android and iOS parity | ArUco means `opencv_dart`: tens of MB of native libraries per ABI, an FFI boundary, and a second numerical stack to keep in step with the golden vectors. |
| Flutter integration burden | C is pure Dart and already runs in `dart test`. A and B do not. |

### The cost side, stated plainly

If A or B wins on detection, it is not free:

- native binary size per ABI, and an FFI boundary in the measurement path;
- a second numerical implementation that the cross-language parity contract
  (`golden-vectors/README.md`) would have to cover;
- coded markers change the badge: design rule **R2** (orientation by marker
  size) is superseded by marker identity, and the quiet-zone and module-size
  requirements are theirs, not ours.

A materially better detection rate on real photographs justifies all of that.
Convenience does not.

## 6. Decision

**Provisional: keep C, on probation.** It is pure Dart, it is fully tested, it
now refuses rather than guessing, and it is good enough on synthetic fixtures
to proceed to the experiment that matters.

**Revisit — mandatory — when dossier V0 images exist.** Re-run this harness on
photographs, add A and B in Python, and record the result here. Selection
happens then.

**Trigger to switch early**, without waiting for the full comparison: any
recurrence of a confident wrong pose (§4.1) on real photographs that the
geometry cross-check does not catch.
