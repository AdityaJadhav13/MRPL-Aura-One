# First physical badge — checklist

The bridge from APP-INTEGRATION-01 to M0C. Everything below is data
collection. **Nothing here fits a dose model, and nothing here may.**

Workflow: Profile → **Physical capture test** → specimen → camera → capture →
diagnostics → **Save** → next.

Keep one note per step: what you did, what the diagnostics showed, and any
defect. Evidence first; do not adjust the target, the lighting or the app to
make a number look better.

---

## Before the first photograph

- [ ] Target printed at 100% on a **colour** printer (ADR-0011: a monochrome
      print collapses 6 of 10 reference patches to grey).
- [ ] 100 mm scale bar measured. Badge measures 60.0 × 40.0 mm.
- [ ] Print record block on the sheet filled in.
- [ ] Profile shows App `0.2.0+2`, Algorithm `m0a`, Geometry
      `badge-v1-research`.

## The sequence

1. **Photograph the unexposed target / badge.** Specimen `P0-X0-01`, series
   level `X0`, lighting as you would describe it. Save.

2. **Confirm geometry.** In diagnostics: *Original, with detected geometry* —
   red circles on the four corner fiducials, orange on the secondary markers.
   Every outline should sit on its printed region.
   - [ ] outlines aligned · [ ] misaligned → record which, and by how much

3. **Confirm references.** Green outlines on all ten reference patches, and
   the *Reference correction* section shows a fitted form (`affine3x4` or
   `linear3x3`) and a condition number.

4. **Confirm the sensor ROI.** Magenta outline covers `A1`.

5. **Confirm the blank ROI.** Cyan outline covers `B`.

6. **Confirm the expiry ROI.** Yellow outline covers `E`. It is sampled and
   stored; **nothing interprets it** — no ageing chemistry is validated.

7. **Inspect raw values.** *Sensor, blank and expiry regions*: linear RGB,
   L\*a\*b\*, usable fraction. A usable fraction well below 1 means pixels were
   excluded (glare, clipping) — note it.

8. **Inspect corrected values.** *Reference correction*: withheld-patch ΔE00.
   These are against **design-space** colours, not measured print — relative
   comparison only.

9. **Repeat capture.** Same specimen, same pose, same light, 5–10 times.
   Independent recaptures — lift the phone between shots. This is the
   repeatability baseline everything else is judged against.

10. **Change lighting.** Same specimen, each lighting class you can produce.
    Set the lighting field honestly; it is the independent variable.

11. **Capture X0 / X1 / X2 / X3.** Set the specimen ID and series level for
    each. Several captures per level — one per level has no spread, and the
    comparison will say so.

12. **Compare features.** Research captures → **Compare X0–X3**. For each
    feature: direction, any reversals, and separation between adjacent levels.
    The screen reports; it does not judge. ΔE may not be the best signal —
    look at all of them.

13. **Do NOT fit a dose model.** X1 is not a known exposure. A dose needs a
    reference instrument measuring concentration at the badge plane over the
    exposure: `D_true = ∫ C_reference(t) dt`. Deriving it from the badge's own
    colour would be circular.

14. **Export evidence.** Research captures → share the manifest, and share
    individual captures worth keeping. With the debug build, pull everything
    with `adb … run-as` (see the install checklist).

15. **Record defects.** Anything that needed a workaround is a finding. Use the
    capture id — it identifies the photograph, the build and the algorithm.

---

## Also worth staging on day one

Mark each with **Staged failure** so it never enters an acceptance statistic:
blur · glare · shadow across the references · a covered marker · cropped ·
bent · a black square beside the badge. A refusal is a correct outcome; an
acceptance of one of these is the finding M0C most needs to know about.

## Known limits of this build

| Limit | Consequence |
|---|---|
| Every acquisition threshold is `SYNTHETIC ONLY` | Accept/refuse decisions are provisional. Save refusals — they are the data that sets the real thresholds. |
| Deformation residuals are recorded, not gating | A bent badge is not yet refused. Look at *Deformation — withheld markers*. |
| Preview analysed at ¼ scale, assuming preview and still share a resolution | Compare the preview and still px/mm in diagnostics; the ratio should be about 4. |
| Stills are not EXIF-rotated | Diagnostics may show the original sideways. Measurement is unaffected — the homography is orientation-independent. |
| Worker *Scan* tab is still simulated | By design; see the gap register (G-12). Use the physical capture test. |
