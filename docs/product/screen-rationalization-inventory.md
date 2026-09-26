# Screen rationalization inventory

**APP-PRODUCT-01 Phase 0 · preliminary · 2026-09-27**

Every registered route, with where it lives today, where it belongs in the
approved five-workspace product, and which later phase owns it. The
classification is **preliminary**: nothing is deleted because of this document
(§47). It exists so that each vertical phase starts from a decided scope
instead of rediscovering it.

## Counts, recalculated

| | Before Phase 0 (`75bb983`) | After Phase 0 |
|---|---|---|
| Registered route paths | **85** | **87** |
| — with a path parameter | 4 | 4 |
| — parameterless | 81 | 83 |
| — development-only (absent in prod) | 7 | 9 |
| — taking their subject via `extra` (guarded by `_needs`) | 12 | 12 |

The "82 registered / 74 swept" figure in `PROJECT_STATE.md` predates
MEASUREMENT-INTEGRATION-02 (`/read` and the physical-capture routes). The claim
sweep list (`test/support/prohibited_claims.dart`) now also covers `/dev` and
`/dev/components`.

**Added:** `/dev` (developer and research hub), `/dev/components` (component
catalog). **Deleted:** none.

## Moved routes (old → new)

| Old path | New path | Why |
|---|---|---|
| `/profile/gallery` | `/dev/gallery` | Research/dev tooling is not a child of the worker's own profile (§91) |
| `/profile/worker-previews` | `/dev/worker-previews` | same |
| `/profile/capture` | `/dev/capture` | same |
| `/profile/physical-capture` | `/dev/physical-capture` | same |
| `/profile/physical-capture/camera` | `/dev/physical-capture/camera` | same |
| `/profile/research-captures` | `/dev/research-captures` | same |
| `/profile` (pushed over the shell) | `/profile` (worker shell branch) | Profile is now a worker destination (§6) |

All `/dev` routes are registered only when `simulationAvailable`, and are
tested absent in a production build.

## Classifications

`KEEP` · `MODIFY` · `MERGE_CANDIDATE` · `MOVE_CANDIDATE` · `DEV_ONLY` ·
`REMOVE_CANDIDATE`

Phases: **P1** Auth + Worker Identity · **P2** DoseBand Assignment + Pre-use
Validation · **P3** Worker Home + Monitoring Lifecycle · **P4** Real End-of-Shift
Scanner & Measurement · **P5** Worker History + Result · **P6** Supervisor ·
**P7** HSE · **P8** Management · **P9** Administration + Inventory · **P10**
Central Server + Sync · **P11** Reporting + Privacy-controlled Export · **P12**
Whole-product QA.

Current status is from `docs/design/ui-completion-matrix.md`.

### Authentication and identity

| Route | Screen | Current workspace | Intended workspace | Current purpose | Future purpose | Phase | Class |
|---|---|---|---|---|---|---|---|
| `/splash` | SplashScreen | Auth | All | Branded launch, 1.5 s timer | Necessary initialisation only; no artificial delay (§28) | P1 | MODIFY |
| `/sign-in` | SignInScreen | Auth | All | Demo sign-in; publishes demo credentials | Real authentication; no credential card (§100) | P1 | MODIFY |
| `/select-site` | SiteSelectionScreen | Auth | All | Choose a seeded site | Site resolved from authenticated scope | P1 | MERGE_CANDIDATE (into sign-in/identity) |
| `/select-role` | RoleSelectionScreen | Auth | Presentation only | Free choice of any role | Role comes from authorization (§4); a free switcher survives only as a clearly separated presentation tool | P1 | MOVE_CANDIDATE (→ dev/presentation) |
| `/workspace/:role` | RoleWorkspacePlaceholder | Auth | — | Honest placeholder for Supervisor/Management | Replaced by the real workspaces | P6/P8 | REMOVE_CANDIDATE (when P6 and P8 land) |

### Worker shell (Home · History · Scan · Safety · Profile)

| Route | Screen | Current workspace | Intended workspace | Current purpose | Future purpose | Phase | Class |
|---|---|---|---|---|---|---|---|
| `/home` | HomeScreen | Worker | Worker | State-aware dashboard, 10 states | Worker Home on the v2 system; one dominant action; retire green hero/monitoring card | P3 | MODIFY |
| `/history` | HistoryScreen | Worker | Worker | Local measurement list | Longitudinal worker exposure history | P5 | MODIFY |
| `/scan` | ScanScreen | Worker | Worker | Entry to the scan journey | Context-resolving Scan (new band / active / final read, §58) | P2/P4 | MODIFY |
| `/safety` | SafetyHubScreen | Worker | Worker | Safety hub | Keep; migrate to v2 components | P3 | KEEP |
| `/profile` | ProfileScreen | Worker | Worker | Environment and build info; one dev row | Worker identity (company-authoritative, read-only) | P1 | MODIFY |

### Worker journey (pushed over the shell)

| Route | Screen | Current workspace | Intended workspace | Current purpose | Future purpose | Phase | Class |
|---|---|---|---|---|---|---|---|
| `/work-context` | WorkContextScreen | Worker | Worker | Shift/area/PTW/JSA context | Keep; migrate | P3 | MODIFY |
| `/shift` | ShiftScreen | Worker | Worker | Shift detail | Detail of work context | P3 | MERGE_CANDIDATE (into work context) |
| `/worker-identity` | WorkerIdentityScreen | Worker | Worker | Identity detail | Moves to Profile identity | P1 | MERGE_CANDIDATE (into /profile) |
| `/work-area` | WorkAreaScreen | Worker | Worker | Work area detail | Detail of work context | P3 | MERGE_CANDIDATE |
| `/ptw` | PtwReferenceScreen | Worker | Worker | PTW reference | Keep | P3 | KEEP |
| `/jsa` | JsaReferenceScreen | Worker | Worker | JSA reference | Keep | P3 | KEEP |
| `/toolbox` | ToolboxAcknowledgementScreen | Worker | Worker | Toolbox acknowledgement | Keep | P3 | KEEP |
| `/assign` | BadgeAssignmentScreen | Worker | Worker | Pick specimen / type physical band | QR claim against the registry (atomic, §127) | P2 | MODIFY |
| `/scan-badge` | ScanBadgeQrScreen | Worker | Worker | Honest camera-absent QR placeholder | Real QR scan of a fresh DoseBand | P2 | MODIFY |
| `/verify` | BadgeVerificationScreen | Worker | Worker | Verification of the chosen band | DoseBand Validation / Pre-use Check (§119) | P2 | MODIFY |
| `/prework` | PreWorkCheckScreen | Worker | Worker | Pre-work readiness | Merge with pre-use outcome (READY TO USE / REPLACE / CANNOT VERIFY) | P2 | MERGE_CANDIDATE (with /verify) |
| `/traceability` | BadgeTraceabilityScreen | Worker | Worker/HSE | Lifecycle of the band | DoseBand lifecycle on the canonical `DoseBandLifecycle` | P2 | MODIFY |
| `/active` | ActiveMonitoringScreen | Worker | Worker | Active monitoring | Home's monitoring state | P3 | MERGE_CANDIDATE (into Home) |
| `/end` | EndMonitoringScreen | Worker | Worker | End monitoring | "Complete monitoring & scan" | P3/P4 | MODIFY |
| `/read` | ReadBadgeScreen (+GuidedScanScreen) | Worker | Worker | Real camera for a physical band; simulation for a specimen | Real end-of-shift scanner | P4 | MODIFY |
| `/processing` | ProcessingScreen | Worker | Worker | Pipeline progress | Keep | P4 | KEEP |
| `/result` | ResultScreen | Worker | Worker | Result or refusal | Result experience | P5 | MODIFY |
| `/measurement` | MeasurementDetailScreen | Worker | Worker/HSE | Traceable detail | Keep | P5 | KEEP |

### Safety (pushed over the shell)

| Route | Screen | Current workspace | Intended workspace | Current purpose | Future purpose | Phase | Class |
|---|---|---|---|---|---|---|---|
| `/safety/h2s` | H2sInformationScreen | Worker | Worker | H₂S briefing | Keep | P3 | KEEP |
| `/safety/emergency` | EmergencyScreen | Worker | Worker | Not-configured emergency slots | Organisation-supplied content | P9 (config) | KEEP |
| `/safety/hazard` | HazardReportScreen | Worker | Worker | Disabled handoff | Handoff when integration exists | P10 | KEEP |
| `/safety/occupational-health` | OccupationalHealthScreen | Worker | Worker | Own OH record | Keep | P5 | KEEP |
| `/safety/ptw` | PtwGuidanceScreen | Worker | Worker | PTW guidance | Keep | P3 | MERGE_CANDIDATE (with `/ptw`) |
| `/safety/jsa` | JsaGuidanceScreen | Worker | Worker | JSA guidance | Keep | P3 | MERGE_CANDIDATE (with `/jsa`) |
| `/safety/ppe` | PpeScreen | Worker | Worker | Not-configured PPE | Organisation config | P9 | KEEP |
| `/safety/toolbox` | ToolboxResourcesScreen | Worker | Worker | Demo resources | Organisation documents | P10 | KEEP |
| `/safety/sds` | SdsScreen | Worker | Worker | SDS list, no contents | Organisation documents | P10 | KEEP |
| `/safety/offline` | OfflineDocumentsScreen | Worker | Worker | Nothing downloaded | Offline document cache | P10 | KEEP |

### HSE (shell + detail)

| Route | Screen | Current workspace | Intended workspace | Current purpose | Future purpose | Phase | Class |
|---|---|---|---|---|---|---|---|
| `/hse` | HseDashboardScreen | HSE | HSE · Overview | Demo overview | Overview from real state | P7 | MODIFY |
| `/hse/monitoring` | HseActiveMonitoringScreen | HSE | Supervisor · Monitoring / HSE | Demo live monitoring | Supervisor's team monitoring; HSE read | P6/P7 | MOVE_CANDIDATE (→ Supervisor) |
| `/hse/session` | ActiveMonitoringDetailScreen | HSE | Supervisor/HSE | Demo session detail | Session detail on `MonitoringSession` | P6/P7 | MOVE_CANDIDATE |
| `/hse/exposures` | HseExposureRegisterScreen | HSE | HSE · Exposures | Demo register | Scoped identified register | P7 | KEEP |
| `/hse/review` | HseReviewQueueScreen | HSE | HSE · Reviews | Demo review queue | Real review workflow | P7 | KEEP |
| `/hse/record` | MeasurementReviewScreen | HSE | HSE | Immutable record review | Keep | P7 | KEEP |
| `/hse/disposition` | HseDispositionScreen | HSE | HSE | Disposition (write disabled) | Real disposition | P7 | KEEP |
| `/hse/handoff` | OccupationalHealthHandoffScreen | HSE | HSE | Not connected | Integration | P10 | KEEP |
| `/hse/workers` | HseWorkerSearchScreen | HSE | HSE | Demo search | Scoped search (real data only, §55) | P7 | KEEP |
| `/hse/worker` | WorkerExposureProfileScreen | HSE | HSE | Demo profile | Scoped profile | P7 | KEEP |
| `/hse/exceptions` | ExceptionQueueScreen | HSE | Supervisor · Exceptions / HSE | Demo exceptions by reason | Operational exceptions (Supervisor), scientific (HSE) | P6/P7 | MOVE_CANDIDATE (split) |
| `/hse/inventory` | BadgeInventoryScreen | HSE | Admin · DoseBands | Demo inventory | Inventory belongs to Admin (§124) | P9 | MOVE_CANDIDATE (→ Admin) |
| `/hse/batch` | BatchDetailScreen | HSE | Admin · DoseBands | Demo batch | Lot detail | P9 | MOVE_CANDIDATE (→ Admin) |
| `/hse/calibration` | CalibrationDetailScreen | HSE | HSE | States no calibration exists | Keep | P7 | KEEP |
| `/hse/audit` | AuditTrailScreen | HSE | HSE (occupational) / Admin (system) | Demo audit | Split by data class | P7/P9 | MOVE_CANDIDATE (split) |

### Reporting

| Route | Screen | Current workspace | Intended workspace | Current purpose | Future purpose | Phase | Class |
|---|---|---|---|---|---|---|---|
| `/reporting` | ReportingCentreScreen | Reporting | HSE · Reports / Management · Reports | Demo template list | Split by privacy class: identified (HSE) vs de-identified (Management) | P11 | MODIFY |
| `/reporting/register` | OccupationalRegisterScreen | Reporting | HSE | Demo register | Merge with `/hse/exposures` | P7/P11 | MERGE_CANDIDATE |
| `/reporting/record` | RecordTraceabilityScreen | Reporting | HSE | 13-step chain | Keep | P11 | KEEP |
| `/reporting/report` | ReportDetailScreen | Reporting | HSE/Management | Demo report detail | Keep | P11 | KEEP |
| `/reporting/builder` | ReportBuilderScreen | Reporting | HSE | Demo builder | Keep | P11 | KEEP |
| `/reporting/preview` | ReportPreviewScreen | Reporting | HSE | Preview only | Keep | P11 | KEEP |
| `/reporting/audit-package` | AuditPackageScreen | Reporting | HSE | Demo package | Keep | P11 | KEEP |
| `/reporting/history` | ExportHistoryScreen | Reporting | HSE | Empty by design | Keep | P11 | KEEP |

### Administration

| Route | Screen | Current workspace | Intended workspace | Current purpose | Future purpose | Phase | Class |
|---|---|---|---|---|---|---|---|
| `/admin` | AdminHomeScreen | Admin | Admin · Overview | Counts of what exists | Keep | P9 | MODIFY |
| `/admin/users`, `/admin/users/:userId` | AdminUsersScreen, AdminUserDetailScreen | Admin | Admin · People | Demo directory | Real accounts/roles/scopes; **no exposure data** | P9 | MODIFY |
| `/admin/sites` | AdminSitesScreen | Admin | Admin · People/Org | Seeded sites | Keep | P9 | KEEP |
| `/admin/departments` | AdminDepartmentsScreen | Admin | Admin | Demo departments | Keep | P9 | KEEP |
| `/admin/work-areas` | AdminWorkAreasScreen | Admin | Admin | Seeded areas | Keep | P9 | KEEP |
| `/admin/organisation` | OrganisationConfigurationScreen | Admin | Admin · System | Not configured | Keep | P9 | KEEP |
| `/admin/integrations`, `/admin/integrations/:integrationId` | IntegrationStatusScreen, IntegrationDetailScreen | Admin | Admin · System | All NOT CONNECTED | Keep | P9/P10 | KEEP |
| `/admin/devices`, `/admin/devices/:deviceId` | AdminDevicesScreen, AdminDeviceDetailScreen | Admin | Admin · System | Demo devices | Keep | P9 | KEEP |
| `/admin/retention` | AdminRetentionScreen | Admin | Admin · System | Not configured | Keep | P9 | KEEP |
| `/admin/sync` | AdminSyncScreen | Admin | Admin · System | Nothing synced | Real sync health | P10 | KEEP |
| `/admin/calibration` | CalibrationAdministrationScreen | Admin | Admin · DoseBands | Controls permanently disabled | Keep disabled until S1–S3 | P9 | KEEP |
| `/admin/badges` | BadgeConfigurationScreen | Admin | Admin · DoseBands | Badge configuration | Merge with inventory from HSE | P9 | MERGE_CANDIDATE |
| `/admin/versions` | AdminVersionsScreen | Admin | Admin · System | Versions | Keep | P9 | KEEP |
| `/admin/system` | SystemInformationScreen | Admin | Admin · System | Limitations | Keep | P9 | KEEP |
| `/admin/demo-data` | DemoDataControlsScreen | Admin | Dev | Demo data controls | Move under `/dev` | P9 | DEV_ONLY (MOVE_CANDIDATE → `/dev`) |

### Developer and research (`/dev`, absent in production)

| Route | Screen | Purpose | Phase | Class |
|---|---|---|---|---|
| `/dev` | DeveloperToolsScreen | The one entry to tooling (added) | — | DEV_ONLY |
| `/dev/components` | ComponentCatalogScreen | Design system v2 catalog (added) | — | DEV_ONLY |
| `/dev/gallery` | GalleryScreen | Instrument components | — | DEV_ONLY |
| `/dev/worker-previews` | WorkerPreviewScreen | Seeds worker states | — | DEV_ONLY |
| `/dev/capture` | CaptureHostScreen | Dossier V0 capture | P4 | DEV_ONLY |
| `/dev/physical-capture`, `/dev/physical-capture/camera` | PhysicalCaptureSetupScreen, PhysicalCaptureSessionScreen | M0C bench workflow | P4 | DEV_ONLY |
| `/dev/research-captures` | ResearchCapturesScreen | Saved captures, export, comparison | P4 | DEV_ONLY |

## What is not yet a route

Supervisor (P6) and Management (P8) have no screens; their target navigation
is held as data in `WorkspaceDestinations` and they reach
`/workspace/:role`. Nothing was built for them in Phase 0 (§30).
