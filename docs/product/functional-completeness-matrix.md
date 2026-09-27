# Functional completeness matrix — Product Build v1 (0.3.0+3)

REAL = works against real inputs · LOCAL_REAL = works, on this device only ·
SIMULATED = labelled simulation · NOT_CONNECTED = boundary exists, nothing
behind it · BLOCKED_BY_VALIDATION = waiting on scientific evidence ·
PLANNED = not built.

| Capability | Status | Notes |
|---|---|---|
| Splash, sign-in, sign-out | LOCAL_REAL | Presentation accounts, salted PBKDF2 verifiers |
| Organisation identity (MRPL directory, SSO) | NOT_CONNECTED | Production flavour shows it |
| Session restore | LOCAL_REAL | Person + role only, re-checked |
| Role from identity; controlled workspace switch | LOCAL_REAL | Yashvi: management ⇄ administrator |
| Route gate per workspace | LOCAL_REAL | Navigation only |
| Worker profile (company record, read-only) | LOCAL_REAL | Presentation data; initials, no photos |
| Worker Home states A–E | LOCAL_REAL | B is the check screen itself |
| QR decode on camera frames | REAL | zxing2, pure Dart; not yet run on a phone |
| Typed serial fallback | LOCAL_REAL | Same registry checks |
| DoseBand registry, eligibility | LOCAL_REAL | Presentation inventory |
| Atomic claim | LOCAL_REAL | One device |
| Cross-device claim uniqueness | NOT_CONNECTED | Needs server |
| Pre-use optical readability check | REAL | Real pipeline; thresholds synthetic (M0C open) |
| Chemical defect detection | BLOCKED_BY_VALIDATION | Shown as "not assessed" |
| Monitoring start/end, persistence, restart | LOCAL_REAL | File store + reconciliation |
| Damaged/lost report → interrupted, replacement | LOCAL_REAL | |
| Final scan identity check (QR) | REAL | |
| Real camera capture and optical pipeline | REAL | Physical validation (M0C) open |
| Quantitative H₂S (ppm·h) | BLOCKED_BY_VALIDATION | `unsupportedCalibration` refusal |
| Measurement record, immutability, supersession | LOCAL_REAL | Supersession has no worker UI yet |
| Result/refusal screen, disposal instruction | REAL | |
| History with 7/30/custom periods | LOCAL_REAL | No totals by design |
| Supervisor overview, team, pipeline, exceptions, detail | LOCAL_REAL | Same records; this device only |
| Supervisor close-out of missing final scan | LOCAL_REAL | |
| HSE register, search, filters | LOCAL_REAL | Site scope |
| HSE traceability chain | LOCAL_REAL | Quality report lives in the capture archive |
| HSE review and disposition | LOCAL_REAL | |
| Reports: register, exceptions, incomplete, audit package | LOCAL_REAL | CSV/JSON copy or save on device; unsigned |
| PDF export | PLANNED | Declared unavailable |
| Management overview, monitoring, trends, CSV | LOCAL_REAL | De-identified, small cells suppressed |
| Exposure statistics for management | BLOCKED_BY_VALIDATION | Withheld |
| Admin people, suspend/restore | LOCAL_REAL | Role/scope editing needs directory: NOT_CONNECTED |
| Admin inventory formulation → lot → serial, QR labels | LOCAL_REAL | |
| Admin audit log | LOCAL_REAL | Local, append-only, not tamper-proof |
| Integrations (PTW, JSA, gate pass, ERP, OH, …) | NOT_CONNECTED | |
| Sync, sync queue, conflict resolution | NOT_CONNECTED | States declared, never produced |
| Connectivity detection / offline banner | PLANNED | Nothing depends on network today |
| Calibration package activation | BLOCKED_BY_VALIDATION | S1–S3 open |
| Simulated worker journey | SIMULATED | `/dev` only, marked |
| Physical-device validation of this build | BLOCKED | No phone available in this run |
