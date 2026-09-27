# Dossier V0 — capture runbook

Everything the software side can do without hardware is done. This is the
session that closes M0C, and it needs a person with a printer and a phone.

Budget roughly half a day for one phone, plus an hour per additional phone.

---

## Before the session

### 1. Print the target

```bash
cd measurement-engine
dart run tool/generate_printable_target.dart > ../../measurement-engine/badge-print/badge-v1-target.svg
```

Print `badge-v1-target.svg` **at 100% scale**. In most print dialogs this
means turning *off* "fit to page" or "scale to fit".

Print at least:

| Copy | Purpose |
|---|---|
| 2 × matte paper | The baseline condition |
| 1 × semi-gloss | Produces real specular highlights, which matte does not |
| 1 × deliberately poor (draft mode / low ink / a photocopy of a print) | The print-degradation condition |

### 2. Measure the scale bar — do not skip this

The target carries a printed 20 mm bar. **Measure it with a ruler.**

If it is not 20 mm, the print was rescaled, and every millimetre-space
conclusion drawn from these photographs would be wrong by that factor. Fix the
print settings and print again.

Record the measured length even when it is correct. Record it per print.

### 3. Build and install

```bash
cd app
flutter build apk --flavor dev -t lib/main_dev.dart --debug
# then install on the phone, or:
flutter run --flavor dev -t lib/main_dev.dart
```

The capture screen is **development only**: Profile → Capture. It is compiled
out of production builds by the same guard as the design gallery.

### 4. Record the print metadata

For each printed copy, write down: printer make and model, driver settings,
paper stock, ink or toner, print date, target file version, the scaling
setting used, and the measured scale-bar length. A target without this is a
sheet of paper, not an experimental artefact.

---

## During the session

### What the app does

On opening the capture screen the app loads badge geometry `badge-v1-research`
from the packaged asset, **verifies its SHA-256 against the manifest**, and
refuses to start if it does not match. Then it opens the camera, reports what
that camera can actually do, and starts guidance on the preview stream.

**Auto-capture is deliberately off.** The arming thresholds are provisional,
and a shutter firing on an unvalidated rule would make those thresholds harder
to study rather than easier. Press the shutter yourself.

**The manual shutter does not bypass validation.** The still is re-checked
independently of what the preview said. A refused photograph is data, not a
mistake.

### Record for every capture

The app records device, camera capabilities, requested-versus-applied
settings, preview assessment, still assessment, geometry metrics and the
original bytes. **You** supply what the phone cannot know:

- illumination class — `daylight`, `warm-led`, `cool-led`, `mixed`,
  `low-light`, `strong-directional`
- which printed target (the specific sheet, not the design)
- approximate distance and angle
- whether the capture was a **deliberate failure**, and which kind

That last one matters: deliberate failures are never pooled with valid
acquisitions in any statistic. They exist to test refusal.

### The matrix

For each phone, for each illumination class, capture at least:

| Geometry | |
|---|---|
| Near-normal | phone parallel, badge centred |
| Rotated | roughly 45°, where the fill-ratio floor bites |
| Perspective X | tilt about the long axis |
| Perspective Y | tilt about the short axis |
| Near / far | the distance extremes the guidance still accepts |

Then the deliberate failures, at least once each per phone:

| Failure | Stage it by |
|---|---|
| Motion blur | moving the phone as you press |
| Specular glare | angling the semi-gloss print toward the light |
| Partial shadow | a hand or object casting across the badge |
| Overexposure | strong direct light |
| Underexposure | a dim corner |
| Occluded corner marker | a fingertip or tape over one corner |
| Occluded secondary marker | same, on a mid-edge marker |
| Cropped | badge running off the frame edge |
| **Bent target** | the target taped around a ~25 mm cylinder |
| Contaminated | fingerprint, small stain, scratch, ink mark, crease |

The bent and contaminated captures are the only way to set two thresholds that
currently do not exist at all.

### Preview versus still

For a subset — say 20 captures spread across conditions — note whether the
guidance said `Hold still` immediately before you pressed, and what the app
reported afterwards. Those matched pairs answer whether a preview metric can
ever gate a still.

---

## After the session

1. Pull the archive off the phone. It lives under the app's documents
   directory in `dossier-v0/`, one directory per capture, each with
   `record.json` and the untouched original image.
2. Check `manifest.json` for `incomplete` — those are interrupted captures and
   should be discarded rather than guessed at.
3. Copy the whole tree into `data/lab/` in the repository, preserving
   directory names. **Do not rename files.** Every record describes its own
   capture; renaming detaches the description from the thing described.
4. Fill in `research/dossier-v0-results.md`, replacing UNKNOWN sections with
   OBSERVED ones. Keep the tags.
5. Re-run the fiducial benchmark against the real photographs, and add the
   ArUco and AprilTag comparison that could not be run on synthetic data.

## If only one phone is available

Proceed. But label every finding **DEVICE-SPECIFIC** in the results document,
and do not answer Q7 (cross-device variation) at all. One phone cannot show
whether the pipeline generalises across camera pipelines, and a single-device
result presented without that caveat is the kind of claim this project exists
to avoid making.

## What this session cannot tell us

It is an experiment about the **phone reader**. It involves no H₂S, no
chemistry and no dose. Gates S1 (passive uptake), S2 (chemical integration) and
S3 (selectivity) remain open regardless of how well it goes.
