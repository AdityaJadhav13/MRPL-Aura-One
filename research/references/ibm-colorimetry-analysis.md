# IBM paper-device-colorimetric-analysis — source teardown and DoseBand adaptation

**Repository:** https://github.com/IBM/paper-device-colorimetric-analysis
**Commit inspected:** `2725e26ddc43cc25fb63450f6ec2990364e33ae6` (2022-07-19, "Update README.md")
**License:** BSD-3-Clause (`LICENSE`; `SPDX-License-Identifier: BSD-3-Clause`, "Copyright 2020- IBM Inc.")
**Authors:** Matheus Esteves Ferreira, Jaione Tirapu Azpiroz (IBM Research Brazil)
**Associated publication:** "A mobile soil analysis system for sustainable agriculture", Ademir Ferreira da Silva et al. The README lists the DOI as *TBD*; the dataset is archived at https://archive.materialscloud.org/record/2022.91
**Analyte:** soil pH via AgroPad paper microfluidic devices — **not a gas, not a dosimeter.**

This repository is the opposite of SmART-Form: weak on product, strong on colour science. Its
value to DoseBand is the illumination-compensation machinery, which is the part SmART-Form
lacks entirely.

---

## 1. Repository contents

| File | Role |
|---|---|
| `uIPL_2022_v2.py` | 55 KB library — **all of the algorithms**. ~90 functions plus one `uPad` class. |
| `Calibration Feature Extraction.ipynb` | Extracts per-spot RGB from lab images into a CSV |
| `Colorimetric Model Training.ipynb` | Trains OpenCV logistic-regression classifiers on that CSV |
| `AgroPad Analysis Demo.ipynb` | Applies illumination compensation to an outdoor capture, then the trained models |
| `Illumination_references/Lab-Referece.bmp`, `calibrationML-SOILSEP20.json` | The laboratory reference colours a field capture is mapped back onto |
| `ML_models/SOILSEP20_L0..L4.xml` | Five serialised OpenCV `LogisticRegression` models, one per sensing spot |

Dependencies: `numpy`, `opencv-python`, `scikit-image`, `scikit-learn`, `scipy`, `pandas`,
`matplotlib`, `PIL`.

---

## 2. The illumination-compensation pipeline

This is the part worth learning. `uPad.correct_image` (`uIPL_2022_v2.py:73`) is a **two-stage**
correction, and the staging is the insight.

### Stage 1 — distribution transfer in CIELAB (`color_transf`, `:483`; `adjust_dist`, `:498`)

```python
img_lab = cv2.cvtColor(im_in, cv2.COLOR_RGB2LAB)
adj = adjust_dist(img_lab, TotalGlobalRef.T)
...
adjusted_dist = np.float64(GlobalRefCh[0] + (in_img - mean)*(GlobalRefCh[1]/std))
```

Per channel in Lab, shift the measured distribution to the reference's mean and scale it to the
reference's standard deviation. This is Reinhard-style colour transfer. It is a coarse global
alignment: it removes gross exposure and cast differences before any model is fitted, so the
least-squares stage that follows is not asked to absorb a large offset.

### Stage 2 — least-squares colour correction matrix (`transform_matrix`, `:517`)

```python
def transform_matrix(mtx, ref):
    '''Calculates a transformation matrix between two matrices by using least square method'''
    transform = np.linalg.lstsq(mtx, ref, rcond=None)
    return transform[0]
```

This **is** the directive's §15 formulation `M = X⁺Y`. `np.linalg.lstsq` computes exactly the
pseudo-inverse least-squares solution. `apply_transform` (`:524`) then applies it pixelwise via
`np.tensordot(in_img, transform, axes=(-1,0))` and clips to 0–255.

`color_polyfit` (`:265`) offers the alternative: a **per-channel** polynomial (default degree 3)
fitted with `np.polyfit` independently for R, G and B. Note what this is *not* — it has no cross
terms, so it can reshape each channel's tone curve but cannot correct channel cross-talk or a
hue rotation. When our §15 says "evaluate 3×3 linear CCM, affine CCM, polynomial colour
correction", IBM's `color_polyfit` is a fourth and weaker family that should be labelled as such
in the comparison, not conflated with a polynomial CCM.

### The reference set is thinner than it looks

`colormatrix_total` (`:422`) returns a **4 × 3** matrix: three printed colour spots plus one
white. And the white is not printed at all — `create_white_ref` (`:452`) *synthesises* it by
measuring the spacing of the three colour spots and placing a circular ROI one step beyond the
last one, on bare card substrate:

```python
distancex = np.mean([centerx[1]-centerx[0], centerx[2] - centerx[1]])
positionx = (centerx[2] + distancex) + offset[0]
```

So a 3×3 transform is fitted from four observations. That leaves essentially no residual degrees
of freedom, and — decisively for us — **there are no patches left over to validate the fit.**

---

## 3. Spot localisation

Unlike SmART-Form, there is real detection here, though it is still crop-assisted:

- `PCA_mask` / `PCA_im` (`:690`, `:694`) — reduce RGB to principal components to maximise
  spot/background separation before thresholding
- `threshold` (`:706`) — scikit-image `threshold_li` by default, with isodata/mean/yen available
- `mask_reconstruction` (`:723`) — morphological cleanup
- `find_ranges` (`:763`) / `sort_circles` (`:737`) — locate `n=5` spots and order them, using
  `cart2pol` to sort by angle
- `crop_spots` / `extract_spots` (`:795`, `:802`) — cut each spot out
- `non_zero_analysis` (`:821`), `nonzero_stats` (`:410`) — per-spot statistics that ignore masked
  (zero) pixels

The PCA-then-threshold idea is genuinely useful and cheap: it finds the projection in which the
printed spots separate best from the substrate, rather than assuming a fixed channel will do it.

But `set_card_output` and `set_card_ref` still take an explicit `croplim = [Xmin, Xmax, Ymin,
Ymax]` supplied by the caller. **There is no fiducial detection and no homography here either.**
The card is assumed roughly axis-aligned and pre-cropped. Perspective is never recovered.

---

## 4. Modelling — and one practice to avoid

`Colorimetric Model Training.ipynb` trains `cv2.ml.LogisticRegression` models. Note that this is
**classification into pH classes**, not regression onto a continuous value — the README states
the workflow as "adding a column with the 'Class' of that data based on the pH value". IBM's
system is semi-quantitative by design. Its models therefore transfer to DoseBand as
*machinery*, not as a modelling precedent for a continuous ppm·h estimate.

The cross-validation helper contains:

```python
cv_X_train, cv_X_test, cv_y_train, cv_y_test = train_test_split(X, y, test_size=split_size, shuffle=True)
```

This is a **random row-wise split**. If several rows derive from the same physical AgroPad — and
with five spots per card plus replicate images, they do — then rows from one card appear on both
sides of the split, and the reported accuracy is optimistic.

This is exactly the leakage pattern our directive §29 forbids. It is recorded here not as
criticism of a soil-pH demo, where the stakes are different, but because it is the single
easiest mistake to inherit by copying a notebook. **Our splits are by physical experimental
unit — badge, run, lot, day, phone — and never by row.**

---

## 5. License assessment

**BSD-3-Clause is permissive and compatible with our intended distribution.** Unlike
SmART-Form's GPL-3.0, we may adapt this code directly, provided we:

1. retain the copyright notice and the three-clause text in any redistribution of source;
2. reproduce them in documentation accompanying a binary distribution;
3. do not use "IBM" or the contributors' names to endorse or promote our product without
   permission.

For a Dart reimplementation nothing is *required* beyond attribution hygiene, since the clauses
bind redistribution of the code itself — but we should record provenance regardless, per §4 of
the directive. Concretely: any Dart function whose logic is derived from `uIPL_2022_v2.py`
carries a header naming the repository, the commit hash, the source function and the licence.

This is my engineering reading of the licence, not legal advice.

---

## 6. What DoseBand takes, and what it changes

### Adopt

| IBM technique | Why it earns its place | Where it lands |
|---|---|---|
| **Two-stage correction**: global distribution alignment, then least-squares CCM | Keeps the fitted matrix small and well-conditioned; stops one model absorbing both exposure offset and spectral error | `lib/src/colour/` — but fitted in **linear** RGB, not on 8-bit Lab (see below) |
| **`M = X⁺Y` least squares** | Already our §15 baseline; IBM confirms it is the standard, workable form | `lib/src/colour/correction_fit.dart` |
| **PCA-then-threshold spot localisation** | Cheap, principled, robust to which channel carries contrast | Candidate for ROI refinement *after* homography, not instead of it |
| **Masked (non-zero) ROI statistics** | Naturally supports excluding specular and contaminated pixels | Our §12 robust statistics |
| **Lab-measured reference values stored as data** (`calibrationML-SOILSEP20.json`) | Correction targets belong in a versioned artefact, not in code | Already our `reference_profiles.patch_values`, which stores **measured**, not nominal, print values |

### Change

| IBM choice | DoseBand change | Reason |
|---|---|---|
| Correction fitted on OpenCV 8-bit Lab | Fit in **linear RGB** after sRGB linearisation (§16); convert to Lab afterwards for features only | `cv2.COLOR_RGB2LAB` on a `uint8` image quantises L to 0–255 and operates on gamma-encoded input |
| 3 colour patches + 1 synthesised white, all consumed by the fit | More patches, **split into fit and held-out sets** | A model that validates itself on its own fit points cannot detect its own failure — directive §15 |
| White reference extrapolated geometrically onto bare substrate | Printed, characterised white and black patches at known geometry positions | An extrapolated ROI lands wherever the geometry error puts it, and substrate is not a colour standard |
| Caller-supplied crop limits; no perspective recovery | Fiducials → homography → canonical mm space, with reprojection residual as a rejection criterion | §8 |
| Random `train_test_split(shuffle=True)` | Grouped splits by badge / run / lot / phone | §29 |
| Classification into analyte classes | Continuous dose estimation with explicit censoring outside the validated range | §37, §38 |

### A practical warning this teardown surfaces

IBM's research stack is Python + OpenCV + scikit-learn. Our production engine is pure Dart
(ADR-0003), and our research notebooks (§42) will be Python. That means the same feature must be
computed twice, in two languages, by two different people-hours. If they disagree by even a
little, a model fitted on Python features is applied to Dart features and the error is silent.

This is a real risk and it needs a named mitigation — a shared golden-vector fixture set that
both stacks must reproduce. It is written up in `research/measurement-engine-audit.md`
§ "Risks", R-3.
