# SmART-Form — source teardown and DoseBand adaptation

**Repository:** https://github.com/publiclab/SmART-Form
**Commit inspected:** `0b0dffc38afc839c76e39bbfca60b90777d636c5` (2019-04-04, "add documentation to README.md" — the repository head; the project has been dormant since)
**License:** GNU GPL-3.0 (`LICENSE`, 35 141 bytes, full GPLv3 text)
**Paper:** Zhang S. et al., *Smartphone App for Residential Testing of Formaldehyde (SmART-Form)*, Building and Environment 148 (2019) 567–578. DOI [10.1016/j.buildenv.2018.11.029](https://doi.org/10.1016/j.buildenv.2018.11.029). Local copy: `research/Smartphone App for Residential Testing of Formaldehyde (SmART-Form).pdf`
**Inspected by:** reading the cloned source and the full paper text. Everything below is quoted or line-referenced; nothing is inferred from the abstract.

This is the closest software analogue to DoseBand that exists in the open: a colour-changing
passive badge, a consumer phone, a cumulative exposure model, and a shipped app. It is worth
studying precisely because it is honest about its limits, and because its architecture shows
exactly which shortcuts we cannot afford.

---

## 1. Files inspected

| File | Role |
|---|---|
| `Android/app/src/main/java/edu/osu/siyang/smartform/Fragment/TestFragment.java` | **The entire measurement algorithm.** 1020 lines, of which ~70 are the science. |
| `Android/app/src/main/java/edu/osu/siyang/smartform/Activity/CameraActivity.java` | Capture, fixed centre crop, resize to 250×250 |
| `Android/.../Bean/Photo.java`, `Util/SmartFormJSONSerializer.java` | Test record persistence (JSON files) |
| `iOS/SmART-FORM/CameraViewController.swift` | iOS capture; locks ISO 200, exposure 1/125 |
| `iOS/SmART-FORM/*.swift` | Survey / consent / table UI. **No iOS implementation of the measurement maths was found** — the analysis path appears to be Android-only in this repository. |

---

## 2. The algorithm, exactly as implemented

### 2.1 Optical signal — `getLightness`, `TestFragment.java:969`

```java
redColors += Color.red(c); greenColors += Color.green(c); blueColors += Color.blue(c);
...
double red = (redColors/pixelCount)/255.0;   // and green, blue
double i = (red+green+blue)/3;
return i;
```

The "lightness" is the **arithmetic mean of the three 8-bit sRGB channels**, averaged over
every pixel of the ROI. The paper calls this the intensity `I` of the HSI transform
(§2.3.3), which is correct as a definition of HSI intensity.

Three properties matter for us:

1. **It is computed on gamma-encoded sRGB.** No linearisation. `I` is therefore not
   proportional to radiance, and a ratio of two such values is not a reflectance ratio. It is
   a monotone but non-linear proxy. This is the error our own pipeline specification already
   names ("fitting in gamma-encoded space is a common and silent error",
   `docs/computer-vision/pipeline.md` §3).
2. **It is a plain mean over every pixel**, with no trimming, no outlier rejection and no
   erosion margin. A single specular highlight or a fibre inside the ROI enters the result at
   full weight.
3. **Integer division before the divide.** `redColors/pixelCount` is `int / int`, truncating
   to a whole 0–255 value before being divided by 255.0. Sub-unit precision in the channel
   mean is discarded.

### 2.2 Reference normalisation — `getRatio`, `TestFragment.java:999`

```java
act = Bitmap.createBitmap(bitmap,  50, 150, 50, 50);
ref = Bitmap.createBitmap(bitmap, 150, 150, 50, 50);
ratio = getLightness(act) / getLightness(ref);  // badge intensity / calibrating patch intensity
```

This is the directive's §14 "SmART-Form ratio", and it is confirmed here in source and in the
paper: the ROIs are **50 × 50 pixel blocks inside a 250 × 250 image** (paper, Fig. 4 caption).

The rationale is stated plainly in the paper (§4, Limitations discussion):

> "we know that the badge is a flat surface, while the environment and its lighting are
> unpredictable. We designed the badge to include a calibration patch, where we assumed that
> this portion in the smartphone image encodes variants of the environment. Using this, we are
> able to approximate the albedo computation through calculating the ratio of lightness of the
> reaction and calibration areas."

And the assumption is stated equally plainly:

> "The mathematical light reflectance model we used in our algorithm is a simple linear color
> change ratio between the calibration patch and the reaction patch. This is based on the
> assumption that the indoor environment contains only homogeneous and ambient light."

### 2.3 Geometry — there is none

`CameraActivity.java:474-477`:

```java
mCameraBitmap = Bitmap.createBitmap(cropBitmap, cropBitmap.getWidth()/4,
        cropBitmap.getHeight()/2 - cropBitmap.getWidth()/4,
        cropBitmap.getWidth()/2, cropBitmap.getWidth()/2);
mCameraBitmap = getResizedBitmap(mCameraBitmap, 250, 250);
```

A **fixed centre square crop**, resized to 250×250. The ROI coordinates `(50,150)` and
`(150,150)` are then hard-coded pixel rectangles in that image.

There is no fiducial detection, no homography, no perspective rectification, no scale
estimation and no rotation handling anywhere in the repository. The two ROIs land on the right
part of the badge **only if the user aligned the badge to the on-screen guide well enough**.
Any tilt, rotation, offset or distance error silently moves the sampling window across the
badge, and nothing in the code can detect that it happened.

This is the single largest architectural gap between SmART-Form and what DoseBand needs, and
it is the reason our §7/§8 geometry stage exists.

### 2.4 Dose model — `getReading`, `TestFragment.java:946`

```java
private double getReading(Bitmap after) {
    double ratio = getRatio(after);
    double result = (-36301*ratio + 36671)/getHour();
    return result;
}
```

**Verified against the paper.** Fig. 7 caption: "The best-fit line to the data was
y = −36301x + 36671 (R² = 0.8811 and P < 0.0001)". The directive's quotation of these
coefficients is accurate.

The units resolve as: `y` = cumulative exposure in **ppb·hr**, `x` = the colour change ratio.
Dividing by elapsed hours converts cumulative exposure back to an average concentration in ppb.
So the shipped app's output is `C_avg = E / T` — exactly the operation our directive §0 permits
only with a valid dose and a valid duration, and forbids presenting as an instantaneous value.

The reciprocity assumption is explicit in the paper (§2.6):

> "CCR = f(E) = f(C × T), where CCR is the color change ratio, E is total exposure, C is
> formaldehyde concentration, and T is time."

**How well was that assumption tested?** Partially. Table 2 shows six chamber tests, all at
23 ± 0.5 °C and all run for 72 h, at target concentrations of 100/50/… ppb, with images taken
repeatedly *during* exposure. So multiple (C, T) pairs do exist in the calibration set and they
were pooled onto one line. That is a weak reciprocity test, not a designed one: the
concentration range is narrow and the profiles are all constant-concentration. Nothing in the
paper varies C and T inversely at fixed E, and nothing tests intermittent exposure. This is
precisely the experiment our directive §26 makes a mandatory gate.

### 2.5 Elapsed time — `getHour`, `TestFragment.java:956`

```java
long timeNow = System.currentTimeMillis();
long timeStart = mTest.getStart().getTime();
double hour = (timeNow - timeStart)/(1000*60*60);
```

Two defects worth recording, because our own implementation must not repeat them:

- **Integer division.** `(long) / (int)` is evaluated as integer division and *then* widened to
  `double`. A 71.9-hour exposure is treated as 71 hours. The truncation error is up to 1.4 % at
  72 h, and far worse for short exposures.
- **Division by zero at short duration.** If the badge is read within the first hour, `hour` is
  `0` and the reading is `Infinity`. Nothing guards this.
- **Wall-clock only.** `System.currentTimeMillis()` is the device clock. A time-zone change, an
  NTP correction or a user edit silently changes the reported concentration. There is no
  monotonic-clock cross-check.

DoseBand already designs against the third of these (`exposure_sessions` carries
`device_clock_start`, `monotonic_start` and `server_time_at_sync`,
`docs/architecture/data-model.md`). The first two are a reminder that the arithmetic deserves
unit tests as much as the colour science does.

### 2.6 The "before" image is captured but not used in the measurement

`TestFragment.java:610`:

```java
Double ratio = getRatio(before);
if(ratio>1) { AlertDialog diaBox = Contaminated(); diaBox.show(); }
```

The pre-exposure photograph is used **only** as a contamination screen — if the unexposed
badge's ratio already exceeds 1, warn the user. It never enters `getReading`, which takes only
the `after` bitmap.

So SmART-Form is, analytically, an **endpoint-only** system that happens to capture a baseline
for QA. That is a directly relevant data point for our §6 decision between endpoint-only and
paired before/after imaging: the closest prior art collects the baseline and then discards it.

### 2.7 Warnings are advisory, not refusals

The paper's Table 1 lists the integrated warnings:

| Condition | Trigger | Action offered |
|---|---|---|
| Overexposure | average lightness > 0.8 | retake photo with less light |
| Low light | average lightness < 0.4 | retake photo with more light |
| Badge contamination | lightness ratio > 1.0 | redo test with a new badge |
| Blue tint from high RH | average saturation < 0.4 | redo test with a new badge |
| Below detection limit | concentration < 20 ppb | "too low to detect" |
| Above detection limit | concentration > 120 ppb | "higher than detectable limit" |

In the source these are `AlertDialog`s (`LowReading()`, `HighReading()`, `HighHumidity()`,
`Contaminated()` in `TestFragment.java:750-800`). They are dismissible messages shown
**alongside a number that is still displayed**. The below-limit dialog reads "Your formaldehyde
concentration is low (<20ppb)" — a quantitative claim made in the same breath as the statement
that the value is below the detection limit.

This is the behaviour DoseBand's `MeasurementResult` sealed union makes structurally
impossible, and it is the clearest illustration of why that union is worth its cost. A warning
the user can dismiss is not a refusal.

---

## 3. Reported analytical performance (and what it cost)

| Quantity | Value | Source |
|---|---|---|
| Calibration fit | y = −36301x + 36671, R² = 0.8811, P < 0.0001 | paper Fig. 7 |
| Detectable range | 20–120 ppb (at 72 h) | abstract; paper §3 |
| Method detection limit | 20 ppb at 72 h, calculated as **3 × SD of blank readings** | paper §2.7, §3 |
| Standard deviation | 10.9 ppb at 72 h exposure, standard orientation to light | abstract; paper §4 |
| Acetaldehyde / VOC co-exposure | no interference (P = 0.93) | abstract, Fig. 7B |
| RH limit | unusable above ~75–80 % RH (artificial blue tint) | paper §4.3 |

### The field-lighting result is the important one

From the field test (paper §3):

> "at location 10 the images taken [under natural light] … was > 64 ppb higher than that
> calculated from the same badges under indoor light (> 120 vs. 56 ppb, 220 % higher)"

and a second location at 80 vs 61 ppb (130 % higher). Same physical badges, same moment,
different illumination — **a factor-of-two error in the reported concentration.**

That is the empirical case against the two-patch lightness ratio as a sufficient colour
correction, made by its own authors in their own field data. It is the strongest single
justification in this literature for DoseBand's multi-patch correction with **withheld**
validation patches: a single neutral reference can normalise brightness, but it cannot
normalise an illuminant's spectrum, and nothing in the two-patch scheme can tell you it
failed.

---

## 4. License assessment

SmART-Form is **GPL-3.0**. The consequences for us are concrete:

- Copying, translating or deriving our Dart code from this Java source would make
  `measurement-engine` — and by linkage the DoseBand application — a derivative work subject
  to GPL-3.0. We would have to license the whole distributed app under GPL-3.0 and provide
  corresponding source. For a badge product intended for an industrial customer, that is a
  decision for the project owner and counsel, not a default.
- **A translation is still a derivative work.** Re-typing `getRatio` in Dart is not laundering.
- What is *not* restricted by copyright: the mathematics, the measured coefficients, the
  published method, and the facts recorded in the paper. Equations and experimental results are
  not copyrightable subject matter.

**Recommendation:** treat SmART-Form as *documentation*, not as a code source. Implement the
ratio feature independently from the published equation and from our own design, cite the
paper, and record in `CATALOG.md` that no SmART-Form source was copied. Nothing in this
teardown requires us to copy any of it — the algorithm is nine lines of arithmetic and we need
a better one anyway.

The GPL analysis above is my reading as an engineer and is **not legal advice**; if any code
reuse is ever contemplated, it needs a lawyer.

---

## 5. Patent note — this repository has IP over it

`research/WO2021146271A1.pdf` is **WO 2021/146271 A1**, "Colorimetric sensor for detection of a
contaminant in the indoor environment and related systems", applicant **Ohio State Innovation
Foundation**, inventors Dannemiller, Qin, Parquette, Gouma — the SmART-Form authors. Filed
2021-01-13, priority 2020-01-13.

Figure 1 of that publication shows a badge with a **reaction area (102)**, a graded
**calibration area (104)**, and **coded markers (106) at the corners** — the same architecture
the directive describes for DoseBand. Google Patents reports the PCT application itself as
ceased, which is unremarkable (the international phase always lapses); **the national-phase
status is what matters and I could not establish it.** See `research/measurement-engine-audit.md`
§ "Open legal questions" — this needs a freedom-to-operate opinion from counsel, not a
developer's web search.

---

## 6. What DoseBand takes, and what it deliberately does not

### Adopt (as concepts, independently implemented)

| Concept | DoseBand form |
|---|---|
| On-badge reference region normalises the unknown illuminant | Kept and **extended**: multiple patches, a fitted correction, and held-out patches that can fail the scan |
| Cumulative-exposure calibration in dose units, with C_avg derived afterwards | Already our contract: `Dose.ppmHours`, with `coverage` as a `Duration` and no normalisation to an 8-h TWA in the engine |
| Acquisition-condition warnings computed from the image itself | Kept and **promoted from advisory to blocking** — our `ResultStatus.poorImage` is a refusal |
| MDL from the blank distribution (3 × SD of blanks) | Candidate method, to be documented and justified per §34 rather than adopted by default |
| Locking camera exposure/ISO before capture (iOS `CameraViewController.swift:44`) | Adopt: capture parameters are measurement metadata, recorded per §11 |

### Reject

| SmART-Form choice | Why |
|---|---|
| Hard-coded ROI rectangles in a fixed centre crop | Undetectable misalignment. Geometry must be recovered from fiducials and validated, per §8. |
| Mean of gamma-encoded RGB as the optical signal | Not proportional to reflectance; all colour maths must happen after linearisation, per §16. |
| Single calibration patch | Cannot correct an illuminant's spectrum and cannot self-diagnose — their own field data shows a 220 % error. |
| Untrimmed mean over all ROI pixels | One highlight corrupts the statistic. Use robust statistics and specular masking, per §12. |
| Warnings that accompany a number | A failure must not be a number. |
| Device wall-clock as the duration source | Needs a monotonic cross-check; already designed in our schema. |

### Open question this teardown raises

SmART-Form captures a baseline and uses it only for QA. Before we commit to paired
before/after imaging (which doubles the worker's interaction cost and adds a second
alignment-failure opportunity), the endpoint-only mode deserves a fair experimental hearing —
our §6 already requires supporting both, and §21's before/after features should be treated as
a hypothesis to test rather than a design commitment.
