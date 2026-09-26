# QRsens — analysis and DoseBand adaptation

**Paper:** Escobedo P., Ramos-Lorente C.E., Ejaz A., Erenas M.M., Martínez-Olmos A., Carvajal M.A., García-Núñez C., de Orbe-Payá I., Capitán-Vallvey L.F., Palma A.J., *QRsens: Dual-purpose quick response code with built-in colorimetric sensors*, Sensors and Actuators B: Chemical **376** (2023) 133001.
**DOI:** [10.1016/j.snb.2022.133001](https://doi.org/10.1016/j.snb.2022.133001)
**Group:** ECsens, University of Granada
**Local copy:** `research/QRsens- Dual-purpose quick response code with built-in colorimeteric sensor.pdf`
**No public source repository was found.** This analysis is from the paper text only; the app is described but not distributed, so there is no code to license or copy.

QRsens matters to us for one reason above all others: **it includes an H₂S sensor**, and it
reports its analytical parameters in full. It is also the origin of the directive's §13
baseline correction.

---

## 1. The correction equations — verified verbatim

The directive quotes two forms. Both are confirmed against the paper, and the distinction
between them is confirmed too.

For every sensor **except** H₂S (paper Eq. 1):

```
                  RGB_sensor − RGB_black_ref
RGB_corrected = 256 · ──────────────────────────
                        RGB_white_ref
```

For the **H₂S sensor specifically** (paper Eq. 2) — "in which a slightly different correction
experimentally delivered better results":

```
                  RGB_sensor − RGB_black_ref
RGB_corrected = 256 · ─────────────────────────────────
                  RGB_white_ref − RGB_black_ref
```

Applied independently to R, G and B. The directive's rendering of both equations, and its
attribution of the second to H₂S, are accurate.

Two observations the paper does not dwell on but we must:

- **Equation 1 is dimensionally odd.** It subtracts black from the numerator but does not
  subtract it from the denominator, so it is not a normalised reflectance and does not map
  black→0, white→256. Equation 2 does. That Eq. 2 was found empirically better for H₂S is
  unsurprising; it is the form that actually spans the reference interval.
- **Neither guards the denominator.** With a damaged, shadowed or clipped white reference,
  `RGB_white − RGB_black` approaches zero and the corrected value explodes. Our §13 requirement
  to "not silently divide by values near zero" is a real defect class, not pedantry.

After correction, RGB is converted to HSV. Quantification uses the normalised hue
`H_norm = H/360` for temperature, RH, H₂S and NH₃; saturation `S` for CO₂ (chosen "because it
delivered a larger variation range").

### The hue discontinuity — a warning about circular features

From the Fig. 5 caption:

> "Note that in the case of H2S, from 1 ppm onwards it is necessary to add 1 unit to Hnorm to
> avoid the discontinuity."

Hue is an angle. It wraps. The authors had to patch the wrap manually with a hard-coded offset
at a hard-coded concentration. That fix depends on knowing in advance which side of the
discontinuity you are on — which is the thing you are trying to measure.

This is a concrete argument for treating hue as a **candidate feature only**, exactly as the
directive §13 insists, and for preferring features that are continuous over the whole response
range. Where a circular quantity must be used, it should be handled as a circular quantity
(unwrapped against a reference, or decomposed into sin/cos), never by an `if concentration > 1`
branch.

---

## 2. Image-processing pipeline as described

1. Photograph taken via an external camera app (Camera Zoom FX) invoked with **fixed settings:
   ISO 800, EV 0.0, autofocus, WB "natural light"**. The paper notes any app would do "as long
   as the camera settings always remain constant."
2. User pinch-zooms to fit the code inside an on-screen white square template; the ROI is
   whatever that square contains, and the rest of the image is discarded.
3. Greyscale conversion → Gaussian blur → **global binary thresholding** (chosen after testing
   alternatives, because "the simplest technique … was the most suitable for our case") →
   **Circle Hough Transform** (OpenCV) to find five circles: three sensors and two B/W
   references.
4. Each detected circle's radius is **reduced by 20 %** before sampling, "to get away from the
   detected circle's edge … in case the edges are blurry."
5. Per circle: location, radius, average RGB and HSV.
6. Sensors are identified from their positions relative to the references.

Two of these are directly worth adopting. The **20 % radius erosion** is the same principle as
our ROI erosion margin, and it is reassuring to see it arrived at independently. **Locking
camera parameters before capture** is the correct instinct and matches our §11.

The rest is weaker than what we need: the alignment is manual, the geometry is never recovered,
and the illumination correction has only two reference points.

---

## 3. Analytical performance — H₂S sensor

From Table 2. The response is fitted with a one-phase exponential growth function
`y = A1·e^(x/A3) + A2`, where `y` is `H_norm`.

| Parameter | Controlled illumination | After light-colour correction |
|---|---|---|
| A1 | −0.37 ± 0.01 | −0.47 ± 0.03 |
| A2 | 1.1802 ± 0.0023 | 1.151 ± 0.007 |
| A3 | −0.273 ± 0.019 | −0.49 ± 0.04 |
| R² | 0.98934 | 0.98213 |
| LOD | 0.01 ppm | 0.13 ppm |
| CV | 1.1 % (at 0.5 ppm) | 2.8 % (at 0.5 ppm) |
| Detection range | 0.01–0.6 ppm | 0.13–0.7 ppm |

**These coefficients are for the QRsens chemistry and must never be used for DoseBand.** They
are recorded so the shape of the response and the cost of the correction are visible.

LOD methodology is stated: `3·s_b` for exponential calibrations; the tangent method for sigmoidal
ones, citing reference [48]. That is the kind of explicit statement our §34 demands of us.

Illumination robustness, Table 1 — maximum standard deviation across three colour temperatures
(3000 K, 4000 K, 5000 K), before and after correction:

| Sensor | SD before | SD after | Reduction |
|---|---|---|---|
| H₂S | 0.24 | 0.06 | 75.0 % |
| Temperature | 0.28 | 0.04 | 85.7 % |
| RH | 0.21 | 0.06 | 71.4 % |
| NH₃ | 0.32 | 0.08 | 75.0 % |
| CO₂ | 0.23 | 0.03 | 87.0 % |

**The correction costs an order of magnitude in LOD** (0.01 → 0.13 ppm) while cutting
illumination-driven spread by 75 %. That trade is worth internalising: a correction that makes
results comparable across illuminants is not free, and the price is paid in sensitivity. Our own
V0 experiment should measure both sides of that trade, not just the spread reduction.

Cross-sensitivity: interference between gases below 3 %, "which in a practical case can be
neglected" — with one exception, NH₃ on the RH sensor (>21 %), for which a linear correction is
given. Nothing is reported about mercaptans, which is the interferent that matters most for a
refinery (see `research/papers.md`, P4).

---

## 4. The decisive limitation for DoseBand

> "The exposure time for the tests was 2 min, time enough to prepare the standard
> analyte/nitrogen mixture and to reach the equilibrium."

QRsens measures **equilibrium concentration**, reversibly, over ~2 minutes, from 0.01 to
0.7 ppm.

DoseBand must measure **cumulative dose**, irreversibly, over an 8-hour shift, and report
ppm·h. These are different measurement modes with different chemistry requirements. A sensor
that equilibrates in two minutes is by construction *not* an integrating dosimeter — it tracks
the current concentration and forgets the past, which is the opposite of what we need.

So QRsens transfers to DoseBand as:

- **an optical and software architecture** — B/W references, geometric localisation, HSV
  quantification, illumination correction — which is fully applicable; and
- **not a chemistry or a calibration precedent** — its response model, its coefficients, its
  ranges and its LOD describe an equilibrium sensor and say nothing about an integrating one.

Conflating the two would be the single most likely way for this project to produce a confident
wrong number.

---

## 5. What DoseBand takes

### Implement as a baseline (directive §13)

Both Eq. 1 and Eq. 2 forms, as **named, versioned candidate features** competing against the
SmART-Form ratio (§14) and the multi-reference CCM (§15), with:

- an explicit denominator-validity check (reject when `|white − black|` falls below a
  threshold derived from sensor noise, rather than dividing and hoping);
- reference-patch integrity validation before either is computed;
- both raw and corrected values stored, per §13.

We should expect the multi-reference CCM to win, because two points cannot characterise a
spectrum. But "expect" is not evidence, and the directive is right that this is decided
experimentally. The QRsens baseline is cheap to implement and gives that comparison a floor.

### Adopt as practice

| QRsens practice | DoseBand form |
|---|---|
| Fixed, recorded camera parameters | §11 — capture metadata is measurement metadata |
| Radius/ROI erosion before sampling (their 20 %) | Already in `docs/computer-vision/pipeline.md` §4 |
| Quantifying illumination robustness as SD across colour temperatures | Adopt directly as a V0 metric — it is a better-designed experiment than "we tested some bulbs" |
| Stating the LOD method explicitly alongside the number | §34 |

### Reject

| QRsens choice | Why |
|---|---|
| Manual pinch-to-fit alignment | No geometry recovery, no way to detect misalignment |
| Two-reference (B/W) correction as the *final* answer | Corrects level, not spectrum; no held-out patch can fail it |
| Normalised hue as the default feature | Circular, with a discontinuity the authors had to hard-code around |
| Equation 1's unnormalised denominator | Use the Eq. 2 form if a two-point correction is used at all |
