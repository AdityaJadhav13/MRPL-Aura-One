# Screen inventory

The complete DoseBand screen set (directive §7 and the group plan §79), with what is
built now versus planned. Status legend: **✅ built** · **◻ planned**.

Everything built in this phase runs on **simulated data**, is marked with the magenta
simulation marker, and reaches the real `MeasurementResult` state machine — no measurement or
MRPL enterprise data is fabricated. Camera/CV is Phase 3; unavailable enterprise integrations
are shown as clean boundaries and marked demo.

## Worker journey (the Section 81 end-to-end path)

| ID | Screen | Route | Status | Notes |
|----|--------|-------|--------|-------|
| 01 | Secure launch / init | `/launch` | ✅ | Indeterminate init, auto-advances |
| 03 | Login / enterprise identity | `/login` | ✅ | Demo identity, no real auth (Phase 7) |
| 04 | Home — no active shift | `/home` | ✅ | Honest empty state + recent records |
| 05 | Home — active monitoring | `/home` | ✅ | Live elapsed; never a live dose |
| 06 | Work context | `/work-context` | ✅ | PTW *referenced*, marked demo |
| 07 | Badge assignment (QR) | `/assign` | ✅ | Simulated picker (camera = Phase 3) |
| 09 | Badge verification | `/verify` | ✅ | Checklist gates eligibility |
| 10 | Pre-work dosimetry check | `/prework` | ✅ | "Ready for dosimetry", never "safe to work" |
| 11 | Start monitoring confirm | `/prework` sheet | ✅ | Confirmation bottom sheet |
| 12 | Active monitoring detail | `/active` | ✅ | Ticking elapsed, not-an-alarm note |
| 13 | End monitoring confirm | `/end` | ✅ | Primary (not destructive) |
| 15 | Guided badge scan | `/read` | ✅ | Simulated guidance + quality lock |
| 17 | Measurement processing | `/processing` | ✅ | Deterministic pipeline stages |
| 18 | Valid quantitative result | `/result` | ✅ | ResultCard + scale |
| 19 | Below quantification | `/result` | ✅ | `< 0.5`, never `0` |
| 20 | Above range / saturated | `/result` | ✅ | `> 40`, retains lower bound |
| 21 | No reading / refused | `/result` | ✅ | `- - -`, what/why/what-to-do |
| 22 | Measurement details | `/measurement` | ✅ | Full traceability sections |
| 23 | Exposure history | `/history` | ✅ | Timeline + filter, all marked simulated |
| 25 | Historical measurement detail | `/measurement` | ✅ | Shared with 22 |
| 26 | Scan hub | `/scan` | ✅ | Routes to the right action for state |
| 29 | Worker profile | `/profile` | ✅ | Pre-existing (Phase 1) |
| 02 | First-time onboarding | — | ◻ | Group G |
| 08 | QR scanner (camera) | — | ◻ | Phase 3 |
| 14 | Scan preparation / how-to | — | ◻ | Group E |
| 16 | Captured image review | — | ◻ | Phase 3 |
| 27 | Offline / sync status | — | ◻ | Marker exists; full screen Group G |
| 28 | Notifications | — | ◻ | Group G |
| 30 | Settings | — | ◻ | Group G |
| 31 | Help / support | — | ◻ | Group G |
| 32 | About / legal / limitations | — | ◻ | Group G |

## Safety officer / HSE (Group H) — all ◻ planned
Overview, exception queue, workers, worker detail, records, review & disposition, audit
timeline.

## Badge operations (Group I) — all ◻ planned
Inventory, badge detail, batch detail, calibration status.

## Site safety (Group J) — all ◻ planned
Safety rules, document library, document viewer, site map (demo), offline map packages,
emergency information, H₂S knowledge card.

## Enterprise (Group K) — all ◻ planned
Records, reports, export/share, audit trail, integration status, retention config.

## Development (Group L)
Component gallery ✅ (Phase 1) · Simulation lab ◻ · SIH demo mode ◻.

## Invariants enforced by tests
- A refusal never renders `0.0` (`test/result/result_invariants_test.dart`).
- Every result carries the simulation marker (same file).
- Valid never renders as "safe" (same file).
- The workflow advances one stage at a time and persists; a refusal returns `Refused` with no
  dose (`test/workflow/workflow_controller_test.dart`).
