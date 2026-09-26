# M0C — physical capture protocol

Written while M0C is **BLOCKED** (see `dossier-v0-results.md`). Its purpose is
that the first hour with a phone and a colour printer is spent capturing
evidence rather than deciding what to capture.

Everything here is preparation. Nothing in it constitutes evidence, and no
conclusion may be drawn from this file.

---

## 0. What M0C is asking

> Can the optical reader reliably acquire and normalise a physical printed badge
> target using a real smartphone under realistic image-capture variation, while
> refusing invalid acquisitions?

It is not chemistry, not calibration, and not dose. The printed target contains
no H₂S chemistry and **no H₂S is required or permitted for M0C**.

**Refusal is a successful outcome.** M0C does not pass because every image
produced a result. It passes if valid acquisitions are accepted *and* invalid
ones are reliably refused.

---

## 1. Prerequisites

| Requirement | Why it is not optional |
|---|---|
| ≥1 physical Android device | §1, §69. Simulator and mock camera cannot satisfy M0C. |
| A **colour** printer | 6 of 10 reference patches are chromatic. Monochrome collapses them to grey levels and destroys the correction's rank. |
| A ruler, ideally a caliper | §8. The print must be measured before anything is photographed. |
| A controlled, uncluttered background | §14 privacy, and §25 false-pose testing needs a known background. |

## 2. Print (§7, §8, §50)

```
cd packages/measurement
dart run tool/generate_print_sheet.dart > geometry/badge-v1-sheet.svg
```

The sheet carries four specimens (S1–S4), a 100 mm scale bar and the print
record block.

1. Print **at 100% / actual size**. Disable fit-to-page, shrink-to-fit and
   scale-to-margins.
2. **Measure the 100 mm bar.** If it is not 100 mm, the print is rescaled —
   fix the print pipeline. Do not compensate by editing canonical geometry.
3. Measure a badge: expected 60.0 × 40.0 mm.
4. Complete the printed record block by hand.
5. Cut specimens apart along the dashed lines.

Print a second sheet if a second printer is available; it is the only way to
separate printer variation from camera variation.

## 3. Capture (§11, §70)

Captures must go through the **actual DoseBand app**, not a phone camera app,
not an uploaded JPEG, not a script.

1. Launch the dev build on the physical Android device.
2. Navigate to the dev capture route (`/profile/capture`, gated on
   `EnvironmentConfig.simulationAvailable`, so it is absent from production).
3. Confirm the geometry version shown is `badge-v1-research`.
4. Place the printed specimen flat.
5. Observe the live guidance and follow it — do not override it from knowledge
   of the correct pose.
6. Capture.
7. Confirm the record persisted: raw image, metadata, rectified image, optical
   features, quality state, acquisition decision, capture id.

Photographs of the target **displayed on a screen do not count** (§72). Screen
targets have different emission spectra, pixel structure and polarisation, and
test nothing about print behaviour. They are useful only as adversarial input.

## 4. Capture matrix

Collect in this order. Start easy; do not tune anything until a baseline
distribution exists (§15).

| Block | Conditions | Directive |
|---|---|---|
| **Baseline** | Flat, perpendicular, diffuse indoor light, no glare, nominal distance. Repeat independently ≥10×. | §15, §16 |
| **Lighting** | diffuse daylight · warm LED · cool LED · low light · directional · partial shadow · mixed · glare | §17 |
| **Pose** | rotation small/moderate/large · perspective X · perspective Y | §18, §20, §21 |
| **Distance** | near · nominal · far, to the point of failure | §19 |
| **Deformation** | mild controlled bend | §22 |
| **Adversarial** | missing marker · covered marker · cropped · distractor squares · printed text · screen-displayed target · other QR · cluttered desk · dark rectangles | §25 |
| **Print degradation** | photocopy · faded · low-contrast · smeared | §26 |
| **Contamination** | fingerprint · dried water spot · pencil mark · scratch · fold | §27 |
| **Blur** | sharp · mild · strong · motion · focus failure | §29 |
| **Exposure** | over · under · torch on/off | §30 |
| **Preview vs still** | both saved from the same acquisition | §41 |

Repeatability means **independent recaptures**, not one image augmented
synthetically (§16).

## 5. Dataset layout (§13)

```
data/m0c-physical/
  sessions/<session-id>/
    captures/<capture-id>/
      original.<ext>        # preserved, never only the rectified crop
      rectified.<ext>
      record.json           # the CaptureRecord
    session.json            # device, printer, specimen, operator, lighting
  README.md
```

Physical data is kept separate from simulated data and from any future lab
calibration or field data. Every row traces to a `capture_id`.

**Privacy (§14):** no faces, ID cards, screens containing secrets, addresses or
unrelated people. No credentials, tokens, location metadata or unnecessary EXIF
in the repository.

## 6. Splitting (§48, §49)

Split **by session**, and preferably by lighting condition, device and print
specimen — never by splitting adjacent frames of one burst, which measures
nothing but frame-to-frame similarity.

- **Development set** — the only data thresholds may be adjusted against.
- **Holdout set** — untouched until decisions are frozen, then read **once**.

Reporting a threshold's performance on the images used to choose it is not
validation, and for a small dataset it is very easy to do by accident.

## 7. What must be reported (§51, §52)

Counts and definitions, never a bare accuracy percentage:

- total captures · valid-target captures · adversarial captures
- correct detections · missed detections · false detections
- **confident wrong poses** — reported separately, never folded into an error rate
- refusals, by reason
- runtime distribution · localisation consistency

**False acceptance is the primary risk.** A refused image can be recaptured; a
confidently wrong pose silently corrupts reference extraction, the sensor ROI
and everything downstream.

## 8. Colour claims (§9, §39, §40)

Without a spectrophotometer, colorimeter or characterised ColorChecker
workflow, M0C may assess **repeatability, relative variation, cross-light
variation, cross-device variation, normalisation consistency and
withheld-reference prediction**.

It may **not** claim absolute colorimetric accuracy, and printed reference
values may not be called CIELAB ground truth. A ΔE computed against nominal
design RGB is not physical colour error.

## 9. Correction comparison (§34, §36, §37)

Compare, on the same real images: raw · black-white normalisation · 3×3 CCM ·
affine. Do not prefer the most complex method by default.

**Withheld-reference validation is mandatory.** A sufficiently flexible
correction fits its own references, so a low fit residual proves nothing. Reserve
patches, correct, then evaluate the reserved ones. Poor holdout performance means
the correction is unreliable however good the fit looks.

## 10. Engine changes (§66, §67)

`packages/measurement` is frozen except for narrowly justified M0C fixes backed
by physical evidence. Every change carries: M0C issue id · physical evidence ·
root cause · minimal fix · test · before/after · impact on goldens and parity.

After any engine change run measurement tests, golden vectors, cross-language
parity, geometry drift and app tests. **If a golden changes, explain why.** Do
not regenerate expected values to make a changed algorithm pass.

## 11. Honest outcomes (§84)

M0C may conclude `PASS`, `PASS WITH OPEN LIMITATIONS`, `FAIL — REDESIGN
REQUIRED`, or `BLOCKED — INSUFFICIENT PHYSICAL EVIDENCE`. A failed experiment is
a result. Do not force a pass.
