# System architecture — Product Build v1

**Status of this document: describes what is implemented in 0.3.0+3 and,
separately, the target it is built toward. Nothing in the "target" column is
deployed.**

## 1. What runs today

```
┌──────────────────────── one phone ────────────────────────┐
│  Flutter app                                              │
│   ├─ five role workspaces (one WorkspaceShell)            │
│   ├─ route gate (navigation only)                         │
│   ├─ operations services  ── access policy (local) ──┐    │
│   ├─ LocalDoseBandRegistry (atomic on this device)   │    │
│   ├─ measurement engine (packages/measurement)       │    │
│   └─ stores (JSON files, app-private, not encrypted) │    │
│        • operations_v1.json   ◀──────────────────────┘    │
│        • shift_session_<worker>.json (per worker)         │
│        • auth_session.json (person + role only)           │
│        • research capture archive (photographs)           │
└───────────────────────────────────────────────────────────┘
          no network calls · no server · no sync
```

| Layer | Implemented as | Status |
|---|---|---|
| Identity | `PresentationIdentityProvider`: six presentation accounts, salted PBKDF2-HMAC-SHA256 verifiers (120 000 iterations, off the UI thread). Production flavour gets `NotConnectedIdentityProvider`. | LOCAL_REAL / NOT_CONNECTED |
| Session restore | `auth_session.json` holds person ID and active role; re-checked against the directory on restore. | LOCAL_REAL |
| Operations store | `OperationsSnapshot` — people, departments, teams, scope grants, formulations, lots, serialised DoseBands, assignments, monitoring sessions, measurement records, HSE reviews, audit log. One file, written atomically (temp + rename); an undecodable file is moved aside, never overwritten. | LOCAL_REAL |
| Atomic claim | `OperationsRepository.transact` serialises every mutation; `LocalDoseBandRegistry.claimWith` re-assesses eligibility inside the transaction. Two claims of one band on one device cannot both win. | LOCAL_REAL |
| Cross-device uniqueness | Requires the central server. | NOT_CONNECTED |
| Authorisation | `OperationsAccess` evaluates every service call against the store: actor must exist, be active, hold the role and a scope grant. Worker = self, supervisor = explicit team, HSE = site grant, management = de-identified only, admin = system data only. | LOCAL_REAL — **SERVER ENFORCEMENT PENDING** |
| Worker journey state | `ShiftSession` per worker, written through to the operations store at claim, start, end and final record; `SessionReconciliation` rebuilds or clears it when the store has moved. | LOCAL_REAL |
| Measurement | Real camera, fiducials, homography, rectification, reference extraction, colour correction, withheld-reference validation, features, quality model; calibration interface returns `unsupportedCalibration` because no validated calibration exists. | REAL / BLOCKED_BY_VALIDATION |
| Sync | None. Every record's sync state is `localOnly`; screens say "stored on this device". | NOT_CONNECTED |

### The three layers of "can this person see this?"

1. **Route gate** (`RouteGate`) — keeps a signed-out person at sign-in and
   each role in its own workspace. Navigation only.
2. **Operations services** (`WorkerView`, `SupervisorView`, `HseView`,
   `ManagementView`, `AdminView` and the matching `*Commands`) — the actual
   boundary in this build. A screen cannot fetch what the service refuses,
   whatever the route.
3. **Server** — the target boundary. Not built.

## 2. Target architecture (not deployed)

```
Flutter app ⇄ local store + sync queue ⇄ authenticated API ⇄ DoseBand server ⇄ relational DB
```

Server responsibilities: identity federation with the organisation
directory, roles and scopes, DoseBand registry with transactional claim
(`UNIQUE (doseband_id) WHERE assignment active`), inventory, sessions,
measurement records (append-only, supersession by reference), HSE review,
reporting, audit, calibration distribution. `supabase/migrations/` holds an
earlier schema sketch; it is a target, not a running service.

The service interfaces in `lib/features/operations/application/` are the
seam: a server-backed `DoseBandRegistry` and repository replace the local
ones without screen changes. Local IDs are time-ordered, counted and random
so they can serve as idempotency keys on upload (§53).

## 3. Offline model

| Works with no network (today: always) | Needs the server (today: not connected) |
|---|---|
| Sign-in to presentation accounts on this device | Organisation sign-in |
| Own profile, today's state, active monitoring | Claim uniqueness across phones |
| Claim within this device's inventory | Live team state from other phones |
| End-of-shift camera scan, engine, record | Organisation-wide HSE register |
| Own history | Central reporting, calibration distribution |

There is no connectivity detector and no sync queue, so no "online",
"synced", "pending" or "last sync" is shown anywhere.

## 4. Status axes (§48)

Five independent fields, never collapsed into "complete":
DoseBand lifecycle (`DoseBandLifecycle`), monitoring session
(`MonitoringSessionState`), measurement result (`ResultStatus`), HSE review
(`ReviewState`), sync (`SyncState`). See `docs/product/lifecycles.md`.
