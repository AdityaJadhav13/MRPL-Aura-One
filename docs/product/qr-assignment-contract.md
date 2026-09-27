# DoseBand QR and assignment contract — v1

## QR payload

```
DOSEBAND:1:DB-2609-0101
```

| Part | Meaning |
|---|---|
| `DOSEBAND` | Scheme. Anything else is "not a DoseBand". |
| `1` | Contract version. A reader names versions it cannot read ("update the app") instead of calling them invalid. |
| `DB-NNNN-NNNN` | Serial = `doseband_id`. |

Version 1 carries **identity only**. Lot, formulation, geometry, expiry and
calibration applicability are looked up in the registry by serial. No
integrity signature exists yet (PLANNED for a later version).

Implementation: `DoseBandQr` (parse/encode), `QrCodec` (pure-Dart zxing2
decode on camera frames and module matrix for labels). The serial can always
be typed instead (`DoseBandQr.normaliseTyped`) and is then checked the same
way.

## Eligibility (registry half of the pre-use check)

`DoseBandEligibility.assess` in order:

1. Unknown serial → REPLACE (`unknownDoseBand`).
2. Worker already holds an unfinished band → "You already have a DoseBand".
3. Lifecycle not `available` → REPLACE (`alreadyAssigned`, `alreadyUsed`,
   `recordedDamaged`, `expired`).
4. Lot expired → REPLACE (`expired`).
5. Lot configuration unsupported → REPLACE (`unsupportedLot`).
6. Otherwise eligible.

## Optical half

A photograph through the real capture pipeline. **Readable** means target,
fiducials, geometry and reference/sensor regions were found and sampled with
no blocking acquisition failure. Colour-correction checks (`reference_fit`,
`withheld_references`) are deliberately not gating here: they decide whether
a *measurement* is trustworthy, at the final scan. This also keeps the known
REF-BLACK behaviour (M0C-3) from turning a good band into "replace".

## Outcomes

| Registry | Photo | Outcome |
|---|---|---|
| not eligible | anything | **REPLACE DOSEBAND** + reason |
| eligible | readable | **DOSEBAND READY TO USE** |
| eligible | not readable / camera unavailable / not taken | **CANNOT VERIFY — TRY AGAIN** ("the DoseBand may be fine") |

A bad photo is never "replace". Chemistry condition is shown as *not assessed*.
Replace and cannot-verify outcomes are written to the audit log for the
supervisor's exception list.

## Claim

`ShiftSessionController.claimAndStart` → `LocalDoseBandRegistry.claimWith`
in one repository transaction: re-assess eligibility, create
`DoseBandAssignment` (with the pre-use record) and a `MonitoringSession`,
move the band `available → assigned`, append an audit event; then start
monitoring (`assigned → monitoring`, session `notStarted → active`).
Typed results: `ClaimAccepted`, `ClaimConflict` (names no one),
`ClaimIneligible(lifecycle)`, `ClaimNotFound`, `ClaimWorkerHasActiveBand`,
`ClaimAuthorityUnavailable`. Re-claiming a band you already hold is
idempotent.

The work context must be recorded before a band is assigned.

## Final scan

The band in hand is identified by QR (`/doseband/scan?purpose=final`) and must
equal the assigned serial before the camera opens for the photograph.
