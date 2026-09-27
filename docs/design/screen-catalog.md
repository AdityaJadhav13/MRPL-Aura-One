# Screen catalog

**Phase:** UI-SURFACE-01 · **Updated:** 2026-09-25

The master implementation map. For each screen: who it is for, where it lives,
what it is for, where its data comes from, what it can actually do, and — the
column that matters most — the safety boundary it has to hold.

Status values are defined in [ui-completion-matrix.md](ui-completion-matrix.md).

---

## 1. Authentication

### Splash — `/splash`
**Role:** all · **Data:** none · **Status:** FUNCTIONAL
Brand entry. Shows MRPL identity, the ONGC subsidiary line, refinery imagery,
the "Safe People / Sustainable Operations" statement and the DoseBand lockup,
then continues to sign-in.
**Boundary:** the pause is branded initialisation. It must never be captioned
"Connecting to MRPL" or "Authenticating" — nothing is being contacted.

### Sign in — `/sign-in`
**Role:** all · **Data:** one published demo account · **Status:** PARTIAL
Employee/Contractor selector, worker ID, password, remember me, forgot
password, gate-pass entry point, and a demo-access card that fills the form.
**Primary action:** Sign In.
**Boundary:** no credential is checked against anything. A refusal says "Demo
credentials do not match" and names no organisation, because none was queried.

### Site selection — `/select-site`
**Role:** all · **Data:** seeded site configuration · **Status:** FUNCTIONAL
**Boundary:** prototype configuration, not a site directory. No claim that a
worker may be assigned to any site.

### Role selection — `/select-role`
**Role:** all · **Data:** static · **Status:** PARTIAL
**Boundary:** a review convenience, not access control. Selecting HSE Officer
does not mean anyone authorised it.

### Unbuilt role workspace — `/workspace/:role`
**Role:** supervisor, management · **Status:** NOT CONNECTED (deliberate)
**Boundary:** an honest placeholder beats routing someone into an interface
built for a different job.

---

## 2. Worker

### Home — `/home`
**Data:** live workflow · **Status:** FUNCTIONAL
A state-aware dashboard: hero, worker identity, today's shift, work context,
monitoring status, one contextual action, a status strip and quick actions.
Ten states, one architecture — see [worker-home.md](worker-home.md).
**Boundary:** an unknown duration renders `- - -`, never `0 h 00 min`. The
green monitoring card is brand identity, never a verdict on exposure.
Connectivity reads "Local · Not synced" because there is no backend.

### Scan — `/scan` · Guided scan — `/read` · Processing — `/processing`
**Data:** live workflow + simulation specimens · **Status:** PARTIAL
**Boundary:** simulated input must never look like a live capture. Processing
shows an indeterminate state, never a fabricated percentage.

### Safety hub — `/safety`
**Status:** FUNCTIONAL — see §3.

### History — `/history`
**Status:** PARTIAL — no history database exists yet (Phase 6).

### Account — `/profile`
**Status:** FUNCTIONAL. Reached from the Home header, not the bottom bar.

### Work context — `/work-context`
**Data:** live workflow · **Status:** FUNCTIONAL
Worker, site, department, work area, shift, job, PTW, JSA, toolbox talk.
**Boundary:** every typed reference is recorded as Manual and rendered with its
provenance chip. Locked once monitoring starts.

### Badge assignment — `/assign` · Verification — `/verify`
**Status:** PARTIAL — a picker over simulation specimens; QR is not connected.
**Boundary:** specimens are marked as simulated and cannot become production
records. Assignment is refused once monitoring has started.

### Pre-work dosimetry check — `/prework`
**Data:** live workflow · **Status:** FUNCTIONAL
Renders `WorkContextValidator`'s actual requirements.
**Boundary:** "Ready for dosimetry" is shown beside permanent copy stating it
does not authorise work or replace PTW, JSA or site safety requirements.

### Active monitoring — `/active` · End monitoring — `/end`
**Status:** FUNCTIONAL
**Boundary:** elapsed time only. No live ppm — a passive badge cannot produce
one. An untrusted window shows `- - -` with the reason.

### Result — `/result` · Measurement detail — `/measurement`
**Status:** PARTIAL
**Boundary:** no calibration exists, so no ppm·h is produced. A refusal keeps
the readout slot visible showing `- - -` and explains what happened, why there
is no number, and what to do next.

---

## 3. Safety

Reached from the worker's Safety tab. Every screen carries a content-source
chip saying whether a statement is general information, a DoseBand product
statement, or something the organisation must supply.

### Safety hub — `/safety`
**Status:** FUNCTIONAL
Emergency and H₂S carry the accent edge and sit first; the rest stays calm. A
safety section rendered in alarm colours becomes wallpaper within a week, and
then the genuinely urgent thing has no way left to stand out.
**Boundary:** the first element, always, is **"DoseBand is not a real-time gas
alarm"**, including that it does not replace portable or fixed detectors.

### H₂S information — `/safety/h2s`
**Status:** FUNCTIONAL (content) · nine sections
What H₂S is · why monitoring matters · real-time detection versus cumulative
monitoring · how the passive badge works · what DoseBand measures · what it does
not · badge handling · limitations · when no result can be given.
**Boundary:** no exposure limits, no alarm set points, no ppm figures, no
symptom tables, no medical claims. Those are jurisdictional and organisational;
quoting one from memory in a refinery app would be a fabrication with the worst
possible consequences. The screen points at the organisation's material for any
figure a worker would act on.

### Emergency — `/safety/emergency`
**Status:** NOT CONNECTED
Five configuration slots, all empty: contacts, assembly point, procedure, site
map, medical contact.
**Boundary:** no invented number, point, route or map, and **no control that
appears to place a call** — a test asserts no digit sequence appears anywhere on
the screen. A wrong number here would be dialled in the one situation where
being wrong costs the most.

### Near miss or hazard — `/safety/hazard`
**Status:** NOT CONNECTED
Four categories described; handoff disabled.
**Boundary:** never "submitted", "reference number" or "success". A button that
appears to file a hazard report and silently does nothing is the most dangerous
control this product could ship.

### Occupational health — `/safety/occupational-health`
**Status:** PARTIAL — shows the real monitoring record, cannot refer
**Boundary:** no diagnosis, no treatment, no health score, no fitness judgement,
and no claim that a referral occurred.

### PTW guidance — `/safety/ptw` · JSA guidance — `/safety/jsa`
**Status:** FUNCTIONAL — content plus the live reference with its provenance
**Boundary:** DoseBand references these processes and does not create, approve,
close, check or replace them. "Ready for dosimetry" is restated as a statement
about the app and nothing else.

### PPE — `/safety/ppe`
**Status:** NOT CONFIGURED
Seven categories listed; requirements absent.
**Boundary:** DoseBand does not recommend PPE from its own readings. It measures
exposure after a period ends; it cannot say what to wear before one begins.

### Toolbox resources — `/safety/toolbox`
**Status:** UI ONLY — demo entries, filterable by category
**Boundary:** opening a resource does not acknowledge a toolbox talk and records
no training or competence.

### Safety data sheets — `/safety/sds`
**Status:** UI ONLY — searchable demo entries
**Boundary:** no contents held, no revision numbers invented, every identifier
prefixed `DEMO-`. View, download and share are present and disabled.

### Offline documents — `/safety/offline`
**Status:** NOT CONNECTED
**Boundary:** nothing downloaded, no storage figure shown. Offline is presented
as normal rather than as an error — the workflow is designed to run with no
signal.

## 4. HSE

Shell: Overview · Monitoring · Exposures · Review. Bottom bar on a phone,
navigation rail at ≥720 px. Worker search, inventory, calibration and audit are
reached contextually rather than taking bar destinations.

Worker UI asks *what should I do next*. HSE asks *what requires my attention* —
so these screens are denser, lead with exceptions, and put filters and review
state above decoration.

### Overview — `/hse`
**Data:** demo · **Status:** UI ONLY
Six metrics (monitoring active, awaiting scan, records complete, review
required, no valid reading, badges in use), a Needs Attention section, active
monitoring, calibration state and system status.
**Boundary:** no tile is coloured by sentiment — a count is neither good nor bad
news, and a green dashboard invites "nothing to do here". System status reads
**Not connected · Last synchronisation: Never**; there is no "synced" state
because there is no backend.

### Active monitoring — `/hse/monitoring` · detail `/hse/session`
**Data:** demo · **Status:** UI ONLY
**Boundary:** an untrusted duration shows `- - -`, never a computed value. No
live ppm — a passive badge cannot produce one. The detail view is observation
only: an officer cannot alter a worker's context, badge or exposure.

### Exposure register — `/hse/exposures`
**Data:** demo · **Status:** UI ONLY
The full occupational field set: worker, ID, employment, contractor, site,
department, area, shift, badge, batch, monitoring window, measurement state,
validity, review state. Search across worker, ID, record, badge and batch;
five secondary filters behind a sheet.
**Boundary:** the exposure column is `- - -` on **every** row, because no record
in this product carries a quantity.

### Measurement review — `/hse/record`
**Data:** demo · **Status:** UI ONLY
Result · validity · worker · work context · monitoring window · badge ·
capture · image quality and reference checks · calibration · algorithm and
versions · environmental context · audit.
**Boundary:** **no editable measurement field exists anywhere on this screen.**
A reviewer decides what to do about a record, not what it says. Unassessed
quality checks read "Not assessed" — never silently as passing. Environmental
context reads "Not recorded", because environment is part of a calibration's
validated domain and its absence has to be visible.

### HSE disposition — `/hse/disposition`
**Data:** demo · **Status:** UI ONLY — write disabled
Workflow states only: In review · Additional information required · Reviewed ·
Closed. A closing decision requires a reason, and that gating is live even
though recording is disabled, so the rule is reviewable.
**Boundary:** no "safe", "unsafe", "medically cleared", "fit for duty" or risk
band. Those are clinical or regulatory judgements a dosimetry app has no
standing to record — and an officer offered the button would eventually press
it. Signature reads "Not applicable": DoseBand holds no signing keys.

### Occupational health handoff — `/hse/handoff`
**Status:** NOT CONNECTED
Minimum necessary information, and an explicit list of what is excluded —
medical information, diagnosis, fitness judgement, other records.

### Worker search — `/hse/workers` · profile — `/hse/worker`
**Data:** demo · **Status:** UI ONLY
**Boundary:** no lifetime or cumulative figure. Summing readings across badges,
periods and contexts would not be defensible even once a calibration exists.

### Exception queue — `/hse/exceptions`
**Data:** demo · **Status:** UI ONLY
Grouped by reason code, filtered by workflow state, counts per state.
**Boundary:** **no severity banding.** A low/medium/high scale is a clinical or
regulatory classification; inventing one would let an officer work down the
queue as though the ordering meant something.

### Badge inventory — `/hse/inventory` · batch — `/hse/batch`
**Data:** demo · **Status:** UI ONLY
**Boundary:** manufacture and expiry are *unavailable*, not estimated. No badge
has been manufactured, and a fabricated supply-chain record gets trusted
without question. No QC, lot-release or shelf-life language.

### Calibration detail — `/hse/calibration`
**Data:** real · **Status:** FUNCTIONAL
States that no production calibration exists, lists S1–S3 as OPEN, and shows
the package fields and performance metrics as **Unavailable** rather than
omitting them — accuracy, LoD, LoQ, RMSE, R², uncertainty, validated range.
Versioning covers Current · Superseded · Research · Unavailable.
**Boundary:** recalibration supersedes for future readings and never rewrites
history — a record keeps the model that produced it.

### Audit trail — `/hse/audit`
**Data:** demo · **Status:** UI ONLY
Timestamp, actor, action, entity, previous → new state, reason, source, device.
**Boundary:** not digitally signed, and the screen says so.

## 5. Reporting and occupational records

Reached from the HSE overview. Reporting asks a different question from the
other surfaces: *what happened, where is the evidence, and how can it be
reviewed?* So these screens lead with traceability, filters and provenance
rather than with actions.

### The rule this subsystem turns on

**No reading is not zero exposure.** Nor is invalid, below quantification,
above range, saturated, partial monitoring or unsupported calibration. Each is
a different fact, and none of them is a number.

This is enforced in the type system rather than by care. `ReportedMeasurement`
declares which states may carry a quantity — only the two simulated-valid ones
— and `MeasurementCell.of` **throws** if a record presents a figure its state
is not entitled to. Every surface formats through that one path, so a table, a
card, a chart label and a report preview cannot disagree.

### Simulated figures

`SimulatedExposure` has exactly one constructor and it always marks its value
simulated. There is no `.measured` and no flag to flip. A production reading
will use the measurement package's `Dose` instead — a different type — so when
calibration arrives the compiler will not let a real result inherit the
simulated presentation.

Every figure renders with a magenta `SIMULATED` chip **beside the number**, and
each screen showing any figure carries a standing banner saying no production
calibration exists. Both are needed: the chip says *this figure is simulated*,
the banner says *and no real figure could exist yet*.

### Reporting centre — `/reporting`
**Status:** UI ONLY
"Start here" leads to the register, builder, audit package and history; the
thirteen report kinds are grouped by category beneath.
**Boundary:** every template is internal. Nothing is labelled compliant.

### Occupational exposure register — `/reporting/register`
**Data:** demo · **Status:** UI ONLY — **the backbone of the subsystem**
The full occupational field set: record, worker, employment, contractor,
department, area, shift, job, PTW, JSA, badge, batch, monitoring window,
completeness, measurement state, exposure, review state. Ten filters behind a
sheet; search across worker, ID, record, badge and batch.
Cards on a phone, a `DataTable` at ≥840 px — a twelve-column occupational table
on a 390-pixel phone is unreadable.

### Record traceability — `/reporting/record`
**Status:** UI ONLY — **the phase exit criterion**
Thirteen numbered steps: worker → shift → work area → job → PTW/JSA → badge →
monitoring window → badge read → measurement → validity → calibration and
software → HSE review → audit.
**Boundary:** read-only. Reporting consumes records; HSE owns review and
disposition, and a second disposition control here would create two places a
record's state could diverge. Quality evidence reads "Not recorded", which is
not the same as "passed".

### Report builder — `/reporting/builder`
**Status:** UI ONLY
Eight steps: type, period, scope, result filters, content, template profile,
preview, export.
**Boundary:** a profile's caveat is rendered with it, always. Profiles naming a
regulator get the heavier treatment.

### Report preview — `/reporting/preview`
**Status:** UI ONLY
Identification, organisation, methodology, summary, records, limitations,
export.
**Boundary:** headed "Preview only"; the report ID reads "Not assigned". **No
mean or total is reported** — records without a figure cannot be averaged, and
excluding them silently would describe a different population than the one
monitored.

### Audit package — `/reporting/audit-package`
**Status:** UI ONLY
Section selection, manifest, pinned versions, integrity.
**Boundary:** the package ID reads "Not assigned"; signature reads "Not
applicable — no signing service exists". Calibration version pins as "None".

### Report history — `/reporting/history`
**Status:** NOT CONNECTED — **empty by design**
**Boundary:** no invented report identifiers. A populated history would be the
clearest possible lie about export: it asserts reports have been produced and
filed.

### Template profiles

| Profile | Permitted wording |
|---|---|
| Internal HSE | Not mapped to any external requirement |
| Organisation profile | Not approved by any organisation |
| **OISD-aligned** | Designed for future OISD mapping. Not yet verified; not reviewed by OISD |
| **DGMS-aligned** | Applicability not established; DGMS has not reviewed DoseBand |
| Custom | User-defined |

No profile name contains "compliant", "approved", "certified" or "verified" —
asserted by a test.

## 5b. Cross-module

### Nothing selected — twelve detail routes
**Status:** FUNCTIONAL
Rendered when a detail route is reached without the record it exists to display
— a typed address, a deep link, or a cold-start restore of the last location.
Those routes carry their subject in `GoRouterState.extra`, which travels with
the navigation call rather than in the URL.
**Boundary:** it states what the screen needs and offers a route back to the
list, rather than rendering an empty detail screen — which would read as a
record that exists and happens to be blank. Before the final audit these routes
threw an uncaught cast exception instead.

## 6. Admin

### Administration home — `/admin`
**Data:** real · **Status:** FUNCTIONAL (index + state summary)
Opens on a count of what actually exists: integrations connected (0 of 11),
devices validated (0 of 3), retention policies configured (0 of 6),
calibration packages installed (none), records synchronised (none).
**Boundary:** those zeros are rendered in the ordinary text colour, neither
green nor red. They are the accurate position of a prototype, not a fault and
not an achievement. Sectioned rather than tabbed — seventeen modules do not fit
a bottom bar.

### Integration status — `/admin/integrations`
**Data:** real · **Status:** FUNCTIONAL
All eleven integrations, all NOT CONNECTED, each opening a detail route.
**Boundary:** the single most important honesty screen in the product. There is
no "Connected" style, because `IntegrationState` has no `connected` value —
adding one requires a source change and a conversation, not a default slipping.

### Integration detail — `/admin/integrations/:id`
**Data:** real · **Status:** FUNCTIONAL
What the integration would do, which direction data would flow, and what its
absence means today. Configure and Test connection are present and disabled.
**Boundary:** "Last success" and "Last attempt" both read *Never*, and both are
null in the model. A sync timestamp on a system with no backend is a fabricated
event, and it is the field a reviewer would most readily believe.

### Users and roles — `/admin/users`
**Data:** demo · **Status:** UI ONLY. No IAM writes.
Lists the role model alongside the directory, with each role's permissions.
**Boundary:** roles are labels, not badges, because a badge reads as a
credential the system issued.

### User detail — `/admin/users/:userId`
**Data:** demo · **Status:** UI ONLY
Identity, authentication state, and the permissions the role would allow.
**Boundary:** every permission reads "Would allow" or "Would not" — never
"Granted". Routing by role is not authorisation: anyone can pick any role at
sign-in and nothing checks. The screen says so in as many words.

### Sites — `/admin/sites` · Departments — `/admin/departments` · Work areas — `/admin/work-areas`
**Data:** real seeded configuration · **Status:** FUNCTIONAL (read-only)
**Boundary:** no hazard classification is stored for an area. Where work
happens says nothing about what the atmosphere contains.

### Organisation configuration — `/admin/organisation`
**Data:** real (prototype config) · **Status:** UI ONLY
Organisation identity, the terminology DoseBand uses for each concept, and the
workflow settings that follow from it.
**Boundary:** read-only. No configuration store exists, so an edit could not be
persisted, and the Edit control says so rather than appearing to save.

### Devices — `/admin/devices`
**Data:** demo · **Status:** UI ONLY
Subtitle carries the real count: *3 registered · none validated*.
**Boundary:** registration and fitness to measure are separate questions. A
handset registers by running the app; nothing has assessed its camera.

### Device detail — `/admin/devices/:deviceId`
**Data:** demo · **Status:** UI ONLY
Device identity, capture capability, measurement validation state, pinned
versions and sync state.
**Boundary:** `DeviceValidationState.validated` exists in the model and nothing
is in it, because M0C is open — no smartphone has yet photographed a printed
target through this application. The screen states that rather than leaving the
absence to be inferred.

### Versions — `/admin/versions`
**Data:** real · **Status:** FUNCTIONAL
App, measurement and data versions, each pinned into every exposure record.
**Boundary:** calibration version reads "None — no production calibration
exists". No release history is shown, because there have been no releases.

### Calibration administration — `/admin/calibration`
**Data:** real · **Status:** NOT AVAILABLE
Package lifecycle governance: what a package will carry, what metrics it will
report, and which scientific gates remain open (S1, S2, S3).
**Boundary:** the whole screen is the most dangerous one in Admin, because an
administration control that could switch on quantitative output would be a path
around scientific validation. Import, Activate and Supersede are present and
permanently disabled. Every performance field reads *Unavailable* — no accuracy,
no LOD, no LOQ, no RMSE, no R², no validated range. A test asserts that no
numeric figure with a unit appears anywhere on it.

### Badge configuration — `/admin/badges`
**Data:** mixed · **Status:** UI ONLY
Geometry, formulation and batch records.
**Boundary:** geometry is displayed, not edited. It is owned by
`measurement-engine` and exported with a SHA-256 manifest; a geometry editable
from an admin text field would be a second source of truth for where a sensor
region is. No badge has been manufactured, so manufacture records, quality
release, shelf life and expiry policy are all empty.

### Retention — `/admin/retention`
**Data:** real · **Status:** NOT CONFIGURED (0 of 6)
One profile per record class, each with period, authority, status, legal hold
and archive state.
**Boundary:** no default retention period ships, and `RetentionProfile.duration`
returns null by construction. A hard-coded duration would be a compliance claim
in a field that looks like configuration. A test rejects "30 years", "7 years",
"as per OISD" and similar.

### Sync health — `/admin/sync`
**Status:** NOT CONNECTED
**Boundary:** the app is local-only. A green "synced" state would be the most
misleading thing this screen could show.

### Demo data controls — `/admin/demo-data`
**Data:** demo · **Status:** DEV ONLY
An index of the demonstration datasets in the build, plus links to the worker
previews and the design gallery.
**Boundary:** gated on `EnvironmentConfig.simulationAvailable` — the route is
not registered in a production build, and a test asserts it. There is no
development-to-production switch on it, and there should not be: production
readiness is a property of the backend, the calibration and the integrations,
not a flag a screen could set.

### Record not found — detail routes
**Status:** FUNCTIONAL
Reached by a stale deep link or a typed URL with an unknown identifier.
**Boundary:** says the record was not found rather than rendering an empty
detail screen, which would read as a record that exists and happens to be blank.

### System information — `/admin/system`
**Data:** real · **Status:** FUNCTIONAL
Versions, environment, and a standing list of product limitations — no
calibration, open gates, no manufactured badge, no optical validation, no
forward clock-jump detection, no integrations, local-only storage.
**Boundary:** this list is how UI progress is prevented from hiding the
scientific state.
