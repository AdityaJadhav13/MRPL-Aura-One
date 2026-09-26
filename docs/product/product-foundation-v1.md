# DoseBand product foundation · v1

**Status:** implementation authority for APP-PRODUCT-01 onwards · 2026-09-27

This document fixes the product model every later phase builds on. Where
something is not built, it says **TARGET**. Nothing here claims a backend, an
integration or a scientific capability that does not exist.

Companion documents: [role-permission-matrix.md](role-permission-matrix.md) ·
[online-offline-matrix.md](online-offline-matrix.md) ·
[screen-rationalization-inventory.md](screen-rationalization-inventory.md) ·
[../design/design-system-v2.md](../design/design-system-v2.md).

---

## 1. Product purpose

DoseBand is a system for recording **cumulative external occupational H₂S
exposure** for individual workers, using a disposable passive colorimetric
wearable read by a smartphone camera.

It is **not** a real-time gas alarm, does not replace fixed or portable gas
detectors, and cannot certify that any atmosphere is safe. Every surface that
could be read otherwise says so.

The system consists of: the disposable physical DoseBand; the smartphone
optical reader; worker, supervisor, HSE, management and administration
workflows; a central server (TARGET); offline-capable mobile operation; and
the measurement, calibration and traceability system.

## 2. The daily disposable operating model

**A worker receives a new DoseBand for every monitoring period.** A DoseBand is
never reused on a following day. The persistent object is the **worker's
exposure history**; the disposable object is the **DoseBand**.

### Start of the monitoring period

```
fresh disposable DoseBand
  → worker scans its QR
  → the system resolves the DoseBand identity
  → the central authority verifies eligibility and uniqueness      (TARGET, §127)
  → physical pre-use check (DoseBand Validation)                   (TARGET, P2)
  → DOSEBAND READY TO USE  |  REPLACE DOSEBAND  |  CANNOT VERIFY — TRY AGAIN
  → worker confirms assignment
  → the DoseBand is ASSIGNED
  → the MonitoringSession begins (ACTIVE)
```

### During monitoring

The worker wears the assigned DoseBand. **The application does not know the
exposure while the band is unread** — a passive badge integrates; it does not
report. No screen shows a live or current concentration.

### End of monitoring

```
worker starts completion
  → the assigned DoseBand's identity is verified
  → real camera acquisition
  → image-quality validation
  → optical measurement pipeline (on device)
  → a calibrated exposure estimate ONLY if a validated calibration applies
     (none exists: S1, S2, S3 are OPEN)
  → the result or the refusal is persisted
  → the MonitoringSession completes
  → the DoseBand leaves service
  → disposal follows the approved site procedure
```

### Next monitoring period

A **new** DoseBand. The lifecycle policy has no transition from any read,
reviewed, failed or exceptional state back to `available` — this is tested.

## 3. DoseBand identity

Each DoseBand carries a unique serialised identity, printed and encoded in its
QR code. Many DoseBands belong to one manufacturing **lot / batch**.

| Concept | Canonical | Technical field today |
|---|---|---|
| One physical band | **DoseBand** (user-facing) | `DoseBand` type (`lib/core/domain/doseband.dart`) |
| Its identity | `dosebandId` / `doseband_id` | `badgeId` / `badge_id` on `BadgeIdentity`, persisted |
| Its manufacturing group | lot / batch (`lotId`) | `batch` / `batchId` |

The existing `badge_id` fields are **not** renamed: they are persisted, and a
broad rename is regression risk with no behavioural gain (§2). `DoseBand.fromIdentity`
is the bridge. User-facing text says **DoseBand**; legacy screens that still say
"badge" are migrated in their phases (debt register).

## 4. QR claiming (TARGET)

Claiming an arbitrary fresh DoseBand **normally requires the central
authority**, because uniqueness is global: two workers scanning the same
available band must not both be assigned it.

- Contract: `DoseBandRegistry` (`lib/core/domain/doseband_registry.dart`).
- Outcomes are typed: `ClaimAccepted`, `ClaimConflict` (someone else holds it —
  **no detail about who**), `ClaimIneligible`, `ClaimNotFound`,
  `ClaimAuthorityUnavailable` (offline / server unavailable / not connected).
- The only implementation today, `NotConnectedDoseBandRegistry`, answers *not
  connected* to everything. **Uniqueness is not faked locally.**
- Atomicity must be enforced by the central relational database (e.g. a
  conditional update on the band's lifecycle), not by the app.

Today's assignment paths — a simulated specimen, or a physical band typed by
hand — do not go through a registry and are labelled as such.

## 5. Pre-use validation (TARGET, P2)

Canonical names: **DoseBand Validation** or **Pre-use Check**. Not "band health".

It may check only conditions that are actually validated: recognised identity;
available lifecycle state; not already assigned; not previously used; expiry
metadata; supported lot/configuration; readable geometry and fiducials; and —
only once validated — abnormal sensor/control/reference appearance and visible
damage.

**A bad image is not a bad DoseBand.** Outcomes:

| Outcome | Meaning |
|---|---|
| DOSEBAND READY TO USE | The *band* is acceptable for assignment. Says nothing about the atmosphere. |
| REPLACE DOSEBAND | The band failed a validated check. Take a new one. |
| CANNOT VERIFY — TRY AGAIN | The check could not be performed (image, connectivity). The band is not judged. |

No claim of comprehensive chemical-defect detection is made.

## 6. Monitoring session

`MonitoringSession` (`lib/core/domain/monitoring_session.dart`): `sessionId`,
`workerId`, `dosebandId`, work-context reference, `startedAt`, `endedAt`,
`state`, measurement reference, provenance.

| Lifecycle | States |
|---|---|
| Operational | NOT_STARTED → ACTIVE → READY_FOR_FINAL_READ → READ_COMPLETE → REVIEWED → CLOSED |
| Exceptional | PARTIAL · INTERRUPTED · BAND_REPLACED · FINAL_READ_MISSING · INVALID_READ |

Transitions are a policy (`MonitoringSessionPolicy`); the UI asks, never
writes. The persisted local `ShiftStage` maps onto it
(`MonitoringSessionStateMapping`).

### Terminology decision

| Term | Is |
|---|---|
| **Monitoring period** (user-facing) = *monitored period* (existing code, 53 uses) | the session — one concept, `MonitoringSession` |
| **Monitoring window** / *exposure window* (existing code, 12 uses) | the session's **time interval**, `startedAt → endedAt` — a property, not a second concept |

They are not duplicates, so nothing was mass-renamed. New user-facing copy says
"monitoring period". An unknown or backwards window is `null`, never zero.

## 7. DoseBand lifecycle

| Kind | States |
|---|---|
| Operational | AVAILABLE → ASSIGNED → MONITORING → READY_FOR_FINAL_READ → READ → REVIEWED → DISPOSED |
| Exceptional | DAMAGED · LOST · INVALID · EXPIRED · ASSIGNMENT_CANCELLED · READ_FAILED · MISSING_FINAL_READ |

Rules (tested): nothing returns to AVAILABLE; DISPOSED is the only terminal
state and every state can reach it; monitoring cannot skip the final read; a
lost band that turns up is disposed of, never reissued. `READ` means the read
*happened*, whatever its result.

## 8. The measurement record

The outcome of a final read is a `MeasurementResult` from the measurement
package — a value **only** when valid, otherwise a typed refusal or censored
state (no reading, below quantification, above range, saturated, unsupported
calibration, result unreliable). **No reading is not 0. Below quantification
is not 0.** The record carries algorithm, geometry, calibration and app
versions, and its data domain (simulated / lab / field).

## 9. Disposal / end of service

After the final read the band leaves service (`read → disposed`, or via
`reviewed`). Disposal follows the approved site procedure; DoseBand records
that it happened, it does not prescribe how.

## 10. Longitudinal exposure record

The worker's history of monitoring periods and their results is the durable
record. It is identified occupational data (Class A). Worker-facing views show
periods and results; no lifetime or cumulative total is shown, because a sum
over results that include refusals would have to treat unknowns as something.

## 11. Roles

Five workspaces: **Worker · Supervisor · HSE Officer · Management · System
Administrator**. Roles are authorization, not themes. See
[role-permission-matrix.md](role-permission-matrix.md). The existing free role
selector is a presentation tool and is scheduled to leave the production path
in P1.

## 12. Privacy model

| Class | Contents | Who |
|---|---|---|
| **A — Identified occupational** | name, photo, worker ID, assignment, monitoring periods, identified exposures, work context | the worker (own); supervisor (team); HSE (authorised scope) |
| **B — De-identified exposure** | exposure information without direct identifiers | management, broader reporting |
| **C — System / operational** | lots, inventory, devices, versions, configuration, integrations, audit | system administrator |

**A System Administrator does not receive Class A access by administering the
software.** Encoded in `DataClass` and `DesignContractAccessPolicy`.

## 13. Central server architecture (TARGET)

```
Flutter mobile application
        ↕
Local operational persistence / sync queue
        ↕
Authenticated API
        ↕
Central DoseBand application server
        ↕
Central relational database
```

Server responsibilities: identity, authentication, RBAC and scope, DoseBand
registry, atomic claiming, inventory, monitoring and measurement records, HSE
workflow, reporting, audit, calibration distribution.

**Phase 0 selects no backend.** ADR-0005 recorded an earlier Supabase
direction; backend selection is to be made deliberately in P10, not because a
plugin is available (§126). No backend code, sync or connection was created.

## 14. Offline-capable mobile architecture

**Server-authoritative, offline-capable — not offline-only.** The final scan,
the measurement engine and local persistence work offline; claiming, global
uniqueness and organisational views need the server. Detail:
[online-offline-matrix.md](online-offline-matrix.md). Canonical states:
`ConnectivityState`, `SyncState` (`lib/core/domain/connectivity.dart`); today
only `localOnly` and `notConnected` are producible, and no count of pending
records exists anywhere.

## 15. Measurement-engine boundary

`packages/measurement` is pure Dart, with no Flutter dependency, and is the
only place optical features, quality decisions and calibration interfaces
live. The app calls it; it never reads app or UI state. **Phase 0 changed zero
files in it.**

## 16. Scientific limitations

- **M0C, S1, S2, S3 are OPEN.** No production calibration exists.
- No ppm or ppm·h figure is produced from a real capture. Simulated figures
  exist only in the simulated domain and are always marked.
- DoseBand targets cumulative external exposure `D = ∫C(t)dt` (ppm·h, once
  calibrated). An equivalent time-average `C_avg = D / T` is only meaningful
  with a validated `D` and a trusted `T`. It is never an instantaneous or live
  concentration.
- Never "H₂S inhaled", "absorbed", or "amount inhaled".
- No accuracy, LoD, LoQ or environmental compensation is claimed.

## 17. Terminology

| Use | Not |
|---|---|
| DoseBand (the band) | badge / patch / band, interchangeably |
| DoseBand ID (`doseband_id`) | — (`badge_id` persists technically) |
| lot / batch | "badge" for a batch |
| monitoring period | shift (for the monitored interval) |
| monitoring window | — (the interval of a period) |
| DoseBand Validation / Pre-use Check | band health |
| DOSEBAND READY TO USE | ready / safe / cleared |
| cumulative H₂S exposure | H₂S inhaled / absorbed |
| final scan / final read | test / check (for the end-of-shift read) |
