# Role and permission matrix

**DESIGN CONTRACT — SERVER ENFORCEMENT PENDING**

No server exists, so nothing below is *enforced*. A check in the app is not
authorization: a modified client can skip it. This matrix is the contract the
UI is built against and the P10 server must enforce. Its executable copy is
`DesignContractAccessPolicy` (`app/lib/features/auth/domain/access_policy.dart`),
and `test/foundation/domain_foundation_test.dart` asserts the rows that matter
most.

Screens ask `policy.allows(role, permission)`; they do not compare role names
(§39). The code's `AppRole.administrator` is this document's **SYSTEM_ADMIN**.

## Scopes

| Scope | Reaches |
|---|---|
| **SELF** | the signed-in person's own records |
| **TEAM** | the workers a supervisor is responsible for |
| **HSE SCOPE** | the site (or sites) an HSE officer is authorised for — decided by the server |
| **DE-IDENTIFIED ORGANISATIONAL** | organisation-wide, direct identifiers removed |
| **SYSTEM ADMIN** | system and operational data only — no occupational exposure |

## Data class × role

| | Worker | Supervisor | HSE Officer | Management | System Admin |
|---|---|---|---|---|---|
| A · Identified occupational | SELF | TEAM | HSE SCOPE (site) | — | — |
| B · De-identified exposure | — | — | HSE SCOPE | ORGANISATION | — |
| C · System / operational | — | — | — | — | ORGANISATION |

## Permissions

| Permission | Worker | Supervisor | HSE | Mgmt | Admin |
|---|:-:|:-:|:-:|:-:|:-:|
| View own profile | ✓ | ✓ | ✓ | ✓ | ✓ |
| View own monitoring | ✓ | | | | |
| View own history | ✓ | | | | |
| Claim a DoseBand | ✓ | | | | |
| Perform the final scan | ✓ | | | | |
| View team identities | | ✓ | | | |
| View team monitoring state | | ✓ | | | |
| View identified exposures (within scope) | | ✓ team | ✓ site | | |
| Review measurements | | | ✓ | | |
| Record disposition | | | ✓ | | |
| View de-identified reports | | | ✓ | ✓ | |
| Export occupational reports | | | ✓ | | |
| Manage accounts | | | | | ✓ |
| Manage roles and scopes | | | | | ✓ |
| Manage DoseBand inventory | | | | | ✓ |
| Manage devices | | | | | ✓ |
| Manage system configuration | | | | | ✓ |
| View system audit | | | | | ✓ |

## Per role

### WORKER — SELF
Own profile, own monitoring period, own DoseBand, own history. Claims a band and
performs the final scan.

### SUPERVISOR — TEAM
Assigned team identities; team monitoring state; team DoseBand assignment state;
identified exposure information **only within the supervisory scope**. No
global worker browsing. Target questions (P6): who is expected, who has / has
not claimed a DoseBand, who is monitoring, who awaits a final scan, who has
completed, who has an operational exception — every count derived from real
state, never seeded.

### HSE_OFFICER — HSE SCOPE
Identified occupational records within the authorised scope; measurement
traceability; review and disposition; occupational reporting. Target record
(P7): worker, work context, DoseBand, monitoring period, measurement, quality
evidence, calibration/algorithm traceability, review.

### MANAGEMENT — DE-IDENTIFIED ORGANISATIONAL
De-identified, aggregated, organisational information by default. **No worker
photo, name or employee ID because the viewer is management.** No
scientifically unsupported organisational exposure metric (no averages over
sets containing refusals).

### SYSTEM_ADMIN — SYSTEM
Accounts, roles, scopes, sites, organisation structure, DoseBand lots and
serialised inventory, devices, geometry versions, calibration packages,
app/system versions, integrations, retention configuration, audit and system
operations. **No automatic identified occupational-exposure privilege.
SYSTEM_ADMIN ≠ HSE_OFFICER.**

## Known gaps against this contract (today's UI)

These are recorded, not fixed, in Phase 0:

- `/select-role` lets anyone choose any role (P1 moves it to a presentation tool).
- `/admin/users` shows demonstration people with employment detail, but no
  exposure data. P9 must keep it that way.
- The HSE shell reaches badge inventory and batch screens that belong to
  Admin (P9 moves them).
- `/reporting` mixes identified registers and de-identified report kinds (P11
  splits them by data class).
