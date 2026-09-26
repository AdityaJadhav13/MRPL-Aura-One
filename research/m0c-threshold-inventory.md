# M0C — capture and quality threshold inventory

**Status of every value in this document: `SYNTHETIC ONLY`.**

Not one threshold below has been observed against a physical photograph. Each
was chosen against generated fixtures during M0A/M0B, where the image formation
was known because we wrote it. That makes them defensible starting points and
nothing more.

Directive §47 requires this inventory before physical capture, so that when real
distributions arrive it is clear exactly what was assumed, by whom, and on what
basis. Directive §48 requires that any revision be made on a development split
and confirmed on an untouched holdout — so the "proposed revised value" column
stays empty until physical data exists to revise against.

**No value here may be described as `PRODUCTION VALIDATED`.** The permitted
statuses are `SYNTHETIC ONLY` → `PROVISIONAL PHYSICAL` → `SUPPORTED FOR M0C
DATASET`, and today every row is in the first.

---

## Fiducial detection — `lib/src/geometry/fiducial_detector.dart`

| Threshold | Value | Origin | Physical observations |
|---|---|---|---|
| `minimumPixels` | 40 | Synthetic: smallest blob that survived downscaling in generated frames. | None |
| `maximumAreaFraction` | 0.25 | Synthetic: rejects a marker filling a quarter of frame, which no valid pose produces. | None |
| `maximumAspectRatio` | 2.2 | Synthetic: tolerates projective foreshortening of a square. | None |
| `minimumFillRatio` | 0.42 | Synthetic, **revised during M0B** after rotated squares under-filled their bounding box. | None |
| binarisation `tolerance` | 0.12 | Synthetic. | None |

`minimumFillRatio` is the one most exposed. It was already moved once on
synthetic rotation evidence, which tells us the value is sensitive to how the
square is rendered — and a printed, photographed square is rendered by a
process we do not control.

## Geometry validation — `lib/src/geometry/geometry_validation.dart`

| Threshold | Value | Origin | Physical observations |
|---|---|---|---|
| `searchRadiusMm` | 2.0 | Synthetic: window for locating a secondary marker. | None |
| `hasUsableRedundancy` | ≥3 residuals | Structural, not tuned. | None |

**This is the most important group in the inventory**, and the one with the
least evidence. Four correspondences fit a projective homography exactly, so a
zero primary residual proves nothing about planarity — M0A established this
against a synthetically bent target. The secondary markers are the only
redundant evidence, and whether their residuals actually separate a flat badge
from a mildly bent one on a real photograph is untested. §22 exists for this.

## Image quality — `lib/src/quality/image_quality.dart`

| Threshold | Value | Origin | Physical observations |
|---|---|---|---|
| `clipHigh` | 0.99 | Synthetic. | None |
| `clipLow` | 0.01 | Synthetic. | None |
| `specularLuma` | 0.95 | Synthetic glare model. | None |
| `specularChroma` | 0.06 | Synthetic glare model. | None |

The glare pair is a model of glare, not a measurement of it. Real specular
highlights on paper under a point source are the §31 experiment.

## Capture guidance — `lib/src/capture/guidance.dart`

| Threshold | Value | Origin | Physical observations |
|---|---|---|---|
| `minimumPixelsPerMm` | 8.0 | Synthetic: sampling floor for the smallest reference patch. | None |
| `maximumPixelsPerMm` | 40.0 | Synthetic. | None |
| `maximumCentreOffsetFraction` | 0.16 | Synthetic framing rule. | None |
| `maximumTiltRatio` | 1.25 | Synthetic. | None |
| `maximumHighClipFraction` | 0.02 | Synthetic. | None |
| `maximumSpecularFraction` | 0.01 | Synthetic. | None |
| `minimumLumaMean` | 0.18 | Synthetic. | None |
| `maximumLumaMean` | 0.92 | Synthetic. | None |
| `minimumLaplacianVariance` | 1.0e-4 | Synthetic. **Scale-dependent.** | None |

`minimumLaplacianVariance` is the weakest value in the whole inventory. Laplacian
variance is not scale-invariant, so a threshold calibrated at one synthetic
resolution does not transfer to a phone whose still is a different size and
whose ISP applies its own sharpening. §29 exists for this, and the value should
be assumed wrong until a physical distribution says otherwise.

`minimumPixelsPerMm = 8.0` implies the smallest reference patch (3.6 mm) is
sampled at roughly 29 px across. Whether that survives a phone's noise
reduction is §19 and §33.

## Capture stability — `lib/src/capture/stability.dart`

| Threshold | Value | Origin | Physical observations |
|---|---|---|---|
| `requiredFrames` | 5 | Synthetic. | None |
| `maximumPoseDriftPx` | 6.0 | Synthetic. | None |

Both describe handheld motion, which no synthetic fixture contains. §45.

## Reference correction — `lib/src/colour/reference_correction.dart`

| Threshold | Value | Origin | Physical observations |
|---|---|---|---|
| `maximumConditionNumber` | 1.0e6 | Numerical, not perceptual: guards matrix inversion. | None |

A conditioning guard is not a correctness guard. A well-conditioned matrix can
still be a bad correction, which is exactly why §37 makes withheld-reference
validation mandatory rather than optional.

---

## Thresholds that do not exist yet

Recorded because their absence is itself a finding, and because the temptation
once physical data arrives will be to invent them quickly.

| Missing threshold | Why it may be needed | Directive |
|---|---|---|
| Print-quality / contrast floor | M0B found synthetic print fade remained accepted. | §26 |
| Contamination signals | Deliberately plural. A single "contamination score" would hide which signal fired. | §27 |
| Secondary-residual rejection limit | The redundancy exists; the limit that turns it into a refusal does not. | §22 |
| Withheld-reference error limit | Nothing yet converts a poor holdout into a refusal. | §37 |
| Preview/still divergence limit | Nothing yet detects that the still disagrees with the frame the user aimed. | §41 |

Each of these must be derived from observed distributions, on a development
split, and confirmed once on a holdout. None may be guessed now.
