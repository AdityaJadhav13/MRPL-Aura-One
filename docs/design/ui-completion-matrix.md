# UI completion matrix

**Phase:** UI-SURFACE-01 — **FROZEN** · **Updated:** 2026-09-25

Audit record: [final-ui-audit.md](final-ui-audit.md) · Gaps: [functional-gaps.md](functional-gaps.md)

The point of this table is to make the gap between *looks complete* and
*actually works* impossible to miss. A polished screen is not a working
feature, and a reviewer should be able to establish which is which without
reading the source.

## Legend

| Status | Meaning |
|---|---|
| **FUNCTIONAL** | Backed by real application state. Doing something here changes something. |
| **PARTIAL** | Real state, but a meaningful part of the behaviour is missing. |
| **UI ONLY** | Renders demonstration records. No action writes anything. |
| **NOT CONNECTED** | A designed placeholder for an integration that does not exist. |
| **NOT CONFIGURED** | The screen works; the organisation has supplied no value for it. |
| **BLOCKED BY VALIDATION** | The UI is complete and must stay inert until a scientific gate closes. |
| **DEV ONLY** | Compiled out of production builds. |

Every row is one of these. There is no single "done" state, deliberately: a
screen can be visually finished, navigable and fully tested while the thing it
describes does not exist, and that combination is the normal case here rather
than the exception.

**Real data** means the live workflow, session or local store.
**Demo data** means `UiDemoCatalog` — typed rows that describe no real worker
and no real measurement.

---

## Authentication

| Screen | Route | Visual | Nav | Real data | Demo data | Backend | Measurement | Integration | Tests | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| Splash | `/splash` | ✅ | ✅ | — | — | — | — | — | ✅ | FUNCTIONAL |
| Sign in | `/sign-in` | ✅ | ✅ | ✅ | published demo account | — | — | identity | ✅ | PARTIAL — one demo account, verifies nothing |
| Site selection | `/select-site` | ✅ | ✅ | ✅ | — | — | — | site directory | ✅ | FUNCTIONAL (seeded config) |
| Role selection | `/select-role` | ✅ | ✅ | ✅ | — | — | — | RBAC | ✅ | PARTIAL — selector, not access control |
| Unbuilt role workspace | `/workspace/:role` | ✅ | ✅ | — | — | — | — | — | ✅ | NOT CONNECTED (by design) |

## Worker

| Screen | Route | Visual | Nav | Real data | Demo data | Backend | Measurement | Integration | Tests | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| Home | `/home` | ✅ rebuilt | ✅ | ✅ | — | — | — | — | ✅ 10 states | FUNCTIONAL |
| Scan | `/scan` | ✅ | ✅ | ✅ | — | — | — | — | ✅ | FUNCTIONAL |
| Safety hub | `/safety` | ✅ | ✅ | — | — | — | — | — | ✅ | FUNCTIONAL (static content) |
| History | `/history` | ✅ | ✅ | ✅ | — | needed | — | — | ✅ | PARTIAL — no history database |
| Account | `/profile` | ✅ | ✅ | ✅ | — | — | — | — | ✅ | FUNCTIONAL — reached from the identity card |
| Work context | `/work-context` | ✅ | ✅ | ✅ | — | — | — | PTW/JSA | ✅ | FUNCTIONAL |
| Badge assignment | `/assign` | ✅ | ✅ | ✅ | simulation specimens | — | — | — | ✅ | PARTIAL — picker, no QR |
| Scan badge QR | `/scan-badge` | ✅ | ✅ | — | — | — | — | badge registry | ✅ | NOT CONNECTED — camera honestly absent |
| Shift | `/shift` | ✅ | ✅ | ✅ | — | — | — | — | ✅ | FUNCTIONAL |
| Worker identity | `/worker-identity` | ✅ | ✅ | ✅ | — | — | — | identity | ✅ | FUNCTIONAL |
| Work area | `/work-area` | ✅ | ✅ | ✅ | — | — | — | — | ✅ | FUNCTIONAL |
| PTW reference | `/ptw` | ✅ | ✅ | ✅ | — | — | — | PTW | ✅ | FUNCTIONAL |
| JSA reference | `/jsa` | ✅ | ✅ | ✅ | — | — | — | JSA | ✅ | FUNCTIONAL |
| Toolbox acknowledgement | `/toolbox` | ✅ | ✅ | ✅ | — | — | — | — | ✅ | FUNCTIONAL |
| Badge traceability | `/traceability` | ✅ | ✅ | ✅ partial | — | needed | — | supply chain | ✅ | PARTIAL — only observed stages are real |
| Worker previews (dev) | `/profile/worker-previews` | ✅ | ✅ | ✅ | — | — | — | — | ✅ | FUNCTIONAL — dev only |
| Badge verification | `/verify` | ✅ | ✅ | ✅ | — | — | — | — | ✅ | FUNCTIONAL |
| Pre-work check | `/prework` | ✅ | ✅ | ✅ | — | — | — | — | ✅ | FUNCTIONAL |
| Active monitoring | `/active` | ✅ | ✅ | ✅ | — | — | — | — | ✅ | FUNCTIONAL |
| End monitoring | `/end` | ✅ | ✅ | ✅ | — | — | — | — | ✅ | FUNCTIONAL |
| Guided scan | `/read` | ✅ | ✅ | ✅ | — | — | engine | — | ✅ | PARTIAL — simulated read |
| Processing | `/processing` | ✅ | ✅ | ✅ | — | — | — | — | ✅ | FUNCTIONAL |
| Result | `/result` | ✅ | ✅ | ✅ | — | — | calibration | — | ✅ | PARTIAL — no dose exists |
| Measurement detail | `/measurement` | ✅ | ✅ | ✅ | — | — | — | — | ✅ | FUNCTIONAL |
| Dossier capture (dev) | `/profile/capture` | ✅ | ✅ | ✅ | — | — | M0B engine | — | ✅ | FUNCTIONAL — real camera |
| Design gallery (dev) | `/profile/gallery` | ✅ | ✅ | ✅ | — | — | — | — | ✅ | FUNCTIONAL |

## Safety

| Screen | Route | Visual | Nav | Real data | Demo data | Backend | Measurement | Integration | Tests | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| H₂S information | `/safety/h2s` | ✅ | ✅ | — | — | — | — | limits | ✅ | FUNCTIONAL (content) |
| Emergency | `/safety/emergency` | ✅ | ✅ | — | — | — | — | site config | ✅ | NOT CONNECTED — nothing invented |
| Near miss / hazard | `/safety/hazard` | ✅ | ✅ | — | — | — | — | reporting | ✅ | NOT CONNECTED — submit disabled |
| Occupational health | `/safety/occupational-health` | ✅ | ✅ | ✅ record | — | needed | — | OH | ✅ | PARTIAL — shows record, cannot refer |
| PTW guidance | `/safety/ptw` | ✅ | ✅ | ✅ reference | — | — | — | PTW | ✅ | FUNCTIONAL (content + live reference) |
| JSA guidance | `/safety/jsa` | ✅ | ✅ | ✅ reference | — | — | — | JSA | ✅ | FUNCTIONAL (content + live reference) |
| PPE | `/safety/ppe` | ✅ | ✅ | — | categories | — | — | documents | ✅ | NOT CONFIGURED — no requirements invented |
| Toolbox resources | `/safety/toolbox` | ✅ | ✅ | — | ✅ | needed | — | documents | ✅ | UI ONLY |
| Safety data sheets | `/safety/sds` | ✅ | ✅ | — | ✅ | needed | — | documents | ✅ | UI ONLY — no contents held |
| Offline documents | `/safety/offline` | ✅ | ✅ | — | ✅ | needed | — | documents | ✅ | NOT CONNECTED — nothing downloaded |

## HSE

| Screen | Route | Visual | Nav | Real data | Demo data | Backend | Measurement | Integration | Tests | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| Overview | `/hse` | ✅ | ✅ | — | ✅ | needed | — | — | ✅ | UI ONLY |
| Active monitoring | `/hse/monitoring` | ✅ | ✅ | — | ✅ | needed | — | — | ✅ | UI ONLY |
| Monitoring detail | `/hse/session` | ✅ | ✅ | — | ✅ | needed | — | — | ✅ | UI ONLY — observation only |
| Exposure register | `/hse/exposures` | ✅ | ✅ | — | ✅ | needed | calibration | — | ✅ | UI ONLY — full field set, 5 filters |
| Review queue | `/hse/review` | ✅ | ✅ | — | ✅ | needed | — | — | ✅ | UI ONLY |
| Measurement review | `/hse/record` | ✅ | ✅ | — | ✅ | needed | — | — | ✅ | UI ONLY — immutable, no editable value |
| HSE disposition | `/hse/disposition` | ✅ | ✅ | — | ✅ | needed | — | — | ✅ | UI ONLY — reason gating live, write disabled |
| Occupational health handoff | `/hse/handoff` | ✅ | ✅ | — | ✅ | needed | — | OH | ✅ | NOT CONNECTED |
| Worker search | `/hse/workers` | ✅ | ✅ | — | ✅ | needed | — | directory | ✅ | UI ONLY |
| Worker profile | `/hse/worker` | ✅ | ✅ | — | ✅ | needed | — | — | ✅ | UI ONLY — no aggregate exposure |
| Exception queue | `/hse/exceptions` | ✅ | ✅ | — | ✅ | needed | — | — | ✅ | UI ONLY — grouped by reason, no severity |
| Badge inventory | `/hse/inventory` | ✅ | ✅ | — | ✅ | needed | — | — | ✅ | UI ONLY |
| Batch detail | `/hse/batch` | ✅ | ✅ | — | ✅ | needed | — | — | ✅ | UI ONLY — unknowns unavailable |
| Calibration detail | `/hse/calibration` | ✅ | ✅ | ✅ | — | — | **blocked on S1–S3** | — | ✅ | FUNCTIONAL — reports that none exists |
| Audit trail | `/hse/audit` | ✅ | ✅ | — | ✅ | needed | — | — | ✅ | UI ONLY — transitions, no signatures |

## Reporting

| Screen | Route | Visual | Nav | Real data | Demo data | Backend | Measurement | Integration | Tests | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| Reporting centre | `/reporting` | ✅ | ✅ | — | ✅ | needed | — | — | ✅ | UI ONLY |
| **Occupational exposure register** | `/reporting/register` | ✅ | ✅ | — | ✅ | needed | calibration | — | ✅ | UI ONLY — backbone; cards on phone, table ≥840 px |
| Record traceability | `/reporting/record` | ✅ | ✅ | — | ✅ | needed | — | — | ✅ | UI ONLY — 13-step chain, read-only |
| Report detail (×13 kinds) | `/reporting/report` | ✅ | ✅ | — | ✅ | needed | calibration | — | ✅ | UI ONLY |
| Report builder | `/reporting/builder` | ✅ | ✅ | — | ✅ | needed | — | — | ✅ | UI ONLY — 8 steps |
| Report preview | `/reporting/preview` | ✅ | ✅ | — | ✅ | needed | — | — | ✅ | UI ONLY — preview, never "generated" |
| Audit package | `/reporting/audit-package` | ✅ | ✅ | — | ✅ | needed | — | — | ✅ | UI ONLY — manifest, no signing |
| Report history | `/reporting/history` | ✅ | ✅ | — | — | needed | — | — | ✅ | NOT CONNECTED — empty by design |

## Admin

| Screen | Route | Visual | Nav | Real data | Demo data | Backend | Measurement | Integration | Tests | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| Administration home | `/admin` | ✅ | ✅ | ✅ | — | — | — | — | ✅ | FUNCTIONAL — counts real system state |
| Integration status | `/admin/integrations` | ✅ | ✅ | ✅ | — | — | — | all eleven | ✅ | FUNCTIONAL — reports nothing connected |
| Integration detail | `/admin/integrations/:id` | ✅ | ✅ | ✅ | — | needed | — | that one | ✅ | FUNCTIONAL — purpose, direction, blocker |
| Users and roles | `/admin/users` | ✅ | ✅ | — | ✅ | needed | — | IAM | ✅ | UI ONLY |
| User detail | `/admin/users/:userId` | ✅ | ✅ | — | ✅ | needed | — | IAM | ✅ | UI ONLY — permissions described, not granted |
| Sites | `/admin/sites` | ✅ | ✅ | ✅ | — | — | — | directory | ✅ | FUNCTIONAL (seeded config) |
| Departments | `/admin/departments` | ✅ | ✅ | ✅ | — | — | — | — | ✅ | FUNCTIONAL (seeded config) |
| Work areas | `/admin/work-areas` | ✅ | ✅ | ✅ | — | — | — | — | ✅ | FUNCTIONAL (seeded config) |
| Organisation configuration | `/admin/organisation` | ✅ | ✅ | ✅ | — | needed | — | — | ✅ | UI ONLY — read-only, no config store |
| Devices | `/admin/devices` | ✅ | ✅ | — | ✅ | needed | — | — | ✅ | UI ONLY |
| Device detail | `/admin/devices/:deviceId` | ✅ | ✅ | — | ✅ | needed | M0C | — | ✅ | BLOCKED BY VALIDATION — M0C open |
| Versions | `/admin/versions` | ✅ | ✅ | ✅ | — | — | — | — | ✅ | FUNCTIONAL |
| Calibration administration | `/admin/calibration` | ✅ | ✅ | ✅ | — | — | S1/S2/S3 | distribution | ✅ | BLOCKED BY VALIDATION — no package exists |
| Badge configuration | `/admin/badges` | ✅ | ✅ | ✅ | — | needed | — | — | ✅ | UI ONLY — geometry read-only |
| Retention | `/admin/retention` | ✅ | ✅ | ✅ | — | needed | — | policy | ✅ | NOT CONFIGURED — 0 of 6 |
| Sync health | `/admin/sync` | ✅ | ✅ | — | — | needed | — | backend | ✅ | NOT CONNECTED |
| Demo data controls | `/admin/demo-data` | ✅ | ✅ | ✅ | — | — | — | — | ✅ | DEV ONLY — absent from production |
| System information | `/admin/system` | ✅ | ✅ | ✅ | — | — | — | — | ✅ | FUNCTIONAL |
| Record not found | detail routes | ✅ | ✅ | ✅ | — | — | — | — | ✅ | FUNCTIONAL — unknown id, not a blank record |

---

## Summary

| | Count |
|---|---|
| Routes | 74 |
| Worker Home states | 10, one architecture |
| FUNCTIONAL | 27 |
| PARTIAL | 6 |
| UI ONLY | 17 |
| NOT CONNECTED | 9 |

**Every route resolves. There are no dead buttons**: a control whose feature
does not exist navigates to a designed state that says so, or is visibly
disabled with the reason next to it.

## What still has to be built behind these screens

1. **A calibration model.** Blocks every quantitative figure in the product.
   Gates S1, S2 and S3 are open.
2. **A measurement history database.** Drift/SQLite, Phase 6. Until then
   `FileWorkflowStore` holds the current session only, and every HSE and
   reporting screen runs on demo rows.
3. **A report exporter.** No PDF or CSV writer exists; the controls are
   disabled rather than producing an empty file.
4. **Nine enterprise integrations.** None connected. See
   `/admin/integrations`, which lists all eleven of them, each with its own detail route.
5. **QR badge scanning.** The assignment screen is a picker over simulation
   specimens.
6. **Production RBAC.** The role selector is a review convenience.
