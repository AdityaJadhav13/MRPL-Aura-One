# Presentation mode — SIH demonstration fallback

Presentation mode keeps the demonstration video runnable if one device
integration fails on the day. It is **not** scientific validation, and it
never changes the measurement engine.

## Principles

- **The real path is always primary.** Presentation mode is off by default,
  lives only in memory (every restart turns it off), and does not exist in
  production builds.
- **It applies only to the presentation DoseBand, `DB-2609-0024`.** A real band
  scanned from its QR always takes the real path, whatever the setting.
- **Same product, same screens.** The fallback enters the real workflow and
  its domain objects. There is no separate demo flow.
- **The data stays separate.** Presentation records are:
  - `RecordOrigin.presentation` and `DataDomain.simulated`;
  - kept out of HSE registers and reviews, management statistics, supervisor
    views, exceptions, reports and any dataset;
  - visible only in the worker's own History.
- **The engine is never made to pass.** Thresholds, REF-BLACK, fiducials,
  colour correction, CIELAB/ΔE, calibration applicability and quality checks
  are untouched. The fallback runs beside the engine, never through it.

## Levels (use the lowest that works)

| Level | QR identity | Pre-use | Final camera | Result |
|---|---|---|---|---|
| 0 — Full real path | real QR | real optical check | real | real engine (no calibration → "No reading") |
| 1 — QR fallback | Presentation DoseBand | real optical check | real | real engine result, tagged presentation identity |
| 2 — Optical fallback | Presentation DoseBand | real photo taken; deterministic READY | real photo, **archived with the engine's actual outcome** | presentation example |
| 3 — Complete fixture | Presentation DoseBand | deterministic READY, no camera | none ("Analysing DoseBand") | presentation example |

The **presentation example** is a fixed 4.2 ± 0.9 ppm·h under model ID
`PRESENTATION-EXAMPLE`:
- It is never random, so every take shows the same value.
- It appears in the product's own result screen with one line: "Presentation
  example — not a calibrated measurement. No validated H₂S calibration exists
  yet."
- Record details show the origin and why it was used. History shows a small
  *Presentation* tag.

## Filming runbook

1. Sign in (the presentation account is prefilled), or use **Skip** → site →
   role.
2. **Profile → Settings → Presentation controls**: switch on and choose the
   lowest level that works on the day.
3. Home → **Scan new DoseBand**. Scan the real label, or at level 1 and above
   tap **Use Presentation DoseBand**.
4. **Photograph the DoseBand** → *DoseBand ready to use* → **Assign this
   DoseBand** → Monitoring active.
5. To skip the wait: Presentation controls → **Advance to final read**.
   Alternatively, use Home → **Complete monitoring & scan**.
6. **Scan assigned DoseBand** (or **Use Presentation DoseBand**) → camera →
   analysing → result.
7. History → the record → **View measurement details**.
8. Before the next take: Presentation controls → **Reset presentation
   workflow**. Real records and archived photographs stay.

## What to say in the video

| Physically operational today | Demonstrated as intended behaviour |
|---|---|
| Sign-in, roles, authorization, site / role setup | — |
| QR identity from a real label (when it reads) | QR fallback, if used |
| Real camera capture, fiducials, rectification, reference patches, quality engine, typed refusals, capture archive, provenance | — |
| A real reading today: "No reading — no calibration" | A dose value (the presentation example) |
| Workflow: assignment, monitoring, final read, history, HSE / supervisor views | Time compression (Advance to final read) |

No validated H₂S calibration exists. M0C and S1–S3 are open.
