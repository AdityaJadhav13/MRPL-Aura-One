# MRPL work context

**Status:** implemented (WORK-CONTEXT-01). **Scope:** the information a monitored
period is attached to, from worker identity through to the pre-work dosimetry
check.

---

## 1. The boundary, first

DoseBand measures cumulative H₂S exposure. It does **not**:

- authorise work;
- issue, approve, extend, close or validate a Permit to Work;
- create, approve, sign or check a Job Safety Analysis;
- conduct or certify a toolbox talk;
- detect gas in real time, or replace a gas detector or a site alarm;
- replace HSE authorisation or occupational-health procedures.

Everything below the worker's own identity is a **reference to somebody else's
process**. MRPL issues the permit. A supervisor and a crew hold the toolbox talk.
DoseBand writes down which ones an exposure record sits beside, so the reading
can be interpreted later.

The strongest claim any screen makes is **"Ready for dosimetry"**, which means
exactly:

> The minimum information required by DoseBand to begin an exposure-monitoring
> session is present.

It does not mean the job is safe, that the permit is valid, or that work may
proceed. The screen says so in those words, and
`test/workflow/safety_language_test.dart` scans every non-comment line of `lib/`
for phrases that would claim otherwise — `safe to work`, `PTW approved`,
`JSA approved`, `work authorised`, `MRPL verified` and others. That test also
asserts that its own patterns still match a clear breach, so it cannot decay
into a check that passes while checking nothing.

## 2. Domain model

```
WorkerIdentity ─┐
SiteRef ────────┤
Department ─────┤
WorkArea ───────┼──► WorkContext ──► ShiftSession ──► exposure record
WorkShift ──────┤         ▲
JobContext ─────┤         │ build(), only when complete
PtwReference ───┤         │
JsaReference ───┤   WorkContextDraft (every field nullable)
ToolboxTalk ────┘
```

| Type | File | Notes |
|---|---|---|
| `EnterpriseValue<T>`, `EnterpriseDataSource` | `domain/enterprise_value.dart` | Provenance. See §3. |
| `WorkerIdentity`, `WorkerType` | `domain/worker_identity.dart` | Snapshot, not a live view of auth. |
| `SiteRef`, `Department`, `WorkArea`, `WorkShift`, `PtwType` | `domain/work_taxonomy.dart` | Configuration objects. |
| `PtwReference`, `JsaReference`, `ToolboxTalkAcknowledgement`, `JobContext` | `domain/permit_context.dart` | External-process references. |
| `WorkContext`, `WorkContextDraft` | `domain/work_context.dart` | Complete vs in-progress. |
| `WorkContextValidator`, `WorkContextReadiness`, `WorkContextRequirement` | `domain/work_context_validator.dart` | The one readiness rule. |
| `WorkContextRepository`, `DemoWorkContextRepository` | `data/work_context_repository.dart` | Demo configuration + id resolution. |

### Complete versus draft

`WorkContext` has **no nullable required fields**. A partially filled context is
a `WorkContextDraft`, and `draft.build()` is the only bridge — it returns null
unless everything is present and coherent.

This is why "monitoring started without a site" is not a bug that can be
written. It is a state that cannot be constructed.

### Worker identity is a snapshot

`WorkerIdentity` is copied from the signed-in `AuthSession` once, when the
context is committed. It is never re-derived. A shared site handset means a
different worker signing in later is an ordinary Tuesday, and an exposure record
must keep describing the worker it belonged to.

`WorkerType` is declared in the workflow domain rather than reused from the
authentication feature. Stored provenance must survive the sign-in screen being
redesigned; coupling it to a UI enum would make a presentation change a
data-migration event.

## 3. Enterprise provenance

Every enterprise-linked value carries where it came from:

| Source | Chip | Meaning |
|---|---|---|
| `demo` | **Demo** | Seeded demonstration data. Nobody entered it, no system supplied it. |
| `manualEntry` | **Manual** | Typed on this device. Nothing checked it. |
| `organizationIntegration` | **Verified** | Confirmed by an organisation system. **No such integration exists.** |

The invariant:

> A manually entered PTW number must never later be indistinguishable from a PTW
> fetched and verified through an MRPL integration.

This is enforced **structurally**, not by convention.
`EnterpriseValue.verified` is the only route to the verified source, and it
*requires* `verifiedAt`, `externalSystem` and `externalReference`. There is no
way to mark something verified without naming what did the verifying, so a
typed-in value cannot drift into looking authoritative.

`EnterpriseDataSource.availableToday` lists `demo` and `manualEntry` only, and a
test asserts that nothing the app can currently produce is verified. Connecting
an integration therefore has to be a deliberate edit to that list, not something
that happens by accident.

Provenance is rendered by exactly one component — `ProvenanceChip` /
`ProvenanceRow` — so the vocabulary cannot drift between screens, and a value is
never shown somewhere its chip did not follow.

## 4. Required fields

Decided in one place: `WorkContextValidator.assess`.

| Requirement | Required? |
|---|---|
| Worker identity | Yes |
| Contractor company | Yes, **for contractors only** |
| Site | Yes |
| Department | Yes |
| Work area | Yes |
| Shift | Yes |
| Job / activity | Yes |
| PTW reference | Yes |
| JSA reference | Yes |
| Toolbox acknowledgement | Yes |
| DoseBand assigned | Yes |
| DoseBand usable | Yes |
| Permit type | **No** — a worker who knows the number but not the category should not be blocked, and a guessed category is worse than an absent one |
| Work order, supervisor, description, gate pass | **No** — context, not prerequisites |

Blank counts as missing: a job title or reference of `"   "` fails.

Two non-blocking warnings exist. `nothingVerifiedExternally` is true of every
context today and is shown so a worker is never left to assume the references
were checked. `workAreaSiteMismatch` also blocks, because an area from another
site would silently move the record.

`contextIsComplete` is `isReady` with the two badge requirements removed. The
work-context form gates its Continue button on it, so that button and the
pre-work checklist cannot disagree about what "complete" means — a divergence
that existed briefly during this phase and is now pinned by tests.

## 5. The toolbox talk, specifically

A toolbox talk is a conversation between people. DoseBand is not in the room.

What is stored is precisely: *the worker acknowledged, at this time, that the
toolbox-talk status has been recorded for this work context.* The screen says
so, and says it does not replace the organisation's process or evidence that the
talk took place.

There is deliberately **no** field for a supervisor signature, an attendee list
or a "verified by". Inventing any of those would manufacture safety evidence,
which is a considerably worse failure than manufacturing a measurement.

There is also no stored `acknowledged: false`. Withdrawing removes the record,
because a stored negative would read as "DoseBand asked and was told no", which
is not what an absent acknowledgement means.

## 6. Demo configuration

**Nothing here is fetched from any MRPL system.**

- **Departments:** a deliberately small subset — Operations, Maintenance, HSE,
  Projects. MRPL has many more; offering all of them in a worker's selector
  would make the real choice harder to find, not easier. Extending it is one
  line.
- **Work areas:** refinery unit names MRPL is publicly associated with, every
  label suffixed **"— Demo area"** so no screenshot can be read as real area
  configuration. Filtered by site, so a refinery unit cannot be attached to the
  corporate office.
- **Shifts:** prototype only. Windows are display strings; **nothing parses
  them**, and nothing may use them to compute or extend an exposure window.
- **Permit types:** not claimed to be exhaustive or current.

Deliberately absent: internal MRPL area codes, restricted-zone classifications,
and any H₂S risk or concentration banding. Selecting "Sulphur Recovery Unit" says
where the work is. It says **nothing** about what the atmosphere contains, and
inferring one from the other is exactly the fabricated measurement this project
exists to avoid.

## 7. Immutability after monitoring starts

`ShiftSession.contextIsLocked` is true from `ShiftStage.monitoring` onwards.

Before monitoring, everything is editable. From the moment it starts, the
context and the badge stop being form state and become the answer to "whose
reading is this, taken where, during what work".

| Action | Before start | During monitoring |
|---|---|---|
| `setContext` | allowed | throws `WorkflowLockedError` |
| `assignBadge` | allowed | throws `WorkflowLockedError` |
| `startMonitoring` | requires context **and** badge | n/a |

Editing in place would leave a measurement attributed to a site, area, permit or
worker that was not in force while the badge was actually exposed — a record
that looks complete and is quietly wrong, which is worse than one that is
obviously missing. A worker needing a correction ends the period and starts a
new one, so the old record keeps its own provenance.

The guards throw rather than return a failure because no screen offers these
actions during monitoring: reaching them is a defect. The screens cooperate —
the work-context screen becomes a read-only record, and the badge verification
screen refuses with an explanation rather than letting the controller throw at a
worker who arrived from a stale back stack.

`startMonitoring` is guarded independently of the screens. The pre-work check
already refuses to enable its button until the validator is satisfied, but that
is one screen's opinion; from that call onwards a physical badge is accumulating
exposure.

## 8. Persistence

Extends the existing `FileWorkflowStore` / `SessionCodec` seam — no new store,
no SQLite. **Schema 2.** A schema-1 snapshot is discarded, not migrated: nothing
has been released, so there is no version to migrate *from*, and a migration
path would be speculative code for a case that has never existed.

Taxonomy entries are stored by **identifier** and re-resolved from configuration
on load, the same rule badges already followed. Timestamps and free text are
stored verbatim.

### What is refused

`SessionCodec.decode` returns null — and the store falls back to an empty
session — for all of:

| Refused | Why |
|---|---|
| Missing worker, site, badge at a stage that requires them | The workflow could not have written it |
| Unknown work area, department, shift or permit type | Cannot be reconstructed; a gap where provenance should be |
| A work area belonging to a different site | Restoring it would silently move the record |
| Contractor with no company; employee carrying one | Describes a worker the form could not produce |
| Job with no title | |
| Malformed toolbox timestamp, or a missing acknowledgement | |
| **`organizationIntegration` without system, reference *and* timestamp** | Would restore as "Verified" while nothing ever verified it |
| **`demo`/`manualEntry` *carrying* verification fields** | The domain cannot construct it; means the record was edited |
| Unknown provenance source; reference with no value | |
| Foreign schema, truncated file, unparseable timestamp | |

The two provenance rows are the point of the exercise: editing one word in the
snapshot file must not turn a typed-in permit number into one MRPL confirmed.

A fully formed verified value **does** round-trip, and a test asserts it — so
the refusals above are known to be about *malformed* provenance rather than the
codec rejecting verification outright.

## 9. Clock behaviour — unchanged

The previous phase's fix stands and is not weakened here. `coverageAt` remains
`Duration?`. A window that runs backwards yields null, screens print `- - -`
rather than `0 h 00 min`, and a scan over such a window returns
`Refused(resultUnreliable, EXPOSURE_WINDOW_UNTRUSTED)`.

## 10. Integration seams — all NOT CONNECTED

| Seam | Implementation today | Status |
|---|---|---|
| `SiteRepository` | `SeededSiteRepository` | NOT CONNECTED |
| `WorkContextRepository` | `DemoWorkContextRepository` | NOT CONNECTED |
| Identity | `DemoAuthRepository` via `AuthState` | NOT CONNECTED |
| PTW | Manual entry only | NOT CONNECTED |
| JSA | Manual entry only | NOT CONNECTED |
| Gate pass | Manual entry only | NOT CONNECTED |
| Toolbox talk | Worker acknowledgement only | NOT CONNECTED |

There is **no HTTP client, no endpoint, and no fake API** anywhere in this
feature. The whole flow works with no connectivity, which is a hard requirement
for a plant with no signal.

Separate provider interfaces (`PtwProvider`, `JsaProvider`, `GatePassProvider`
and so on) were **not** created. The two repositories that exist earn their keep
today; a dozen single-implementation interfaces for integrations nobody has
specified would be speculative structure, and the provenance model is what
actually makes future integration safe.

## 11. Handoffs deliberately not built

`WorkContext` can later be referenced by HSE review, occupational health and
near-miss reporting. None of those are implemented.

No medical information is stored in `WorkContext`, and none should be added to
it. No exposure is diagnosed. No emergency contacts, assembly points or site
maps are fabricated.

## 12. Known limitations

1. **Forward clock jumps are undetectable.** Unchanged from the previous phase
   and still open. See `docs/design/persistence.md` §4.
2. **The start → kill → relaunch round trip has never run on a physical
   phone.** Covered by real-file-IO tests and a macOS launch; the last mile on
   hardware remains open, the same blocker as M0C.
3. **Site is inherited from sign-in and changed there**, not in the work-context
   form. Simpler than a second selector, and it keeps one source of truth — but
   it means changing site is a trip back through auth.
4. **A draft is not persisted.** A worker who abandons a half-filled form loses
   it. They had not started a monitored period, and storing the fragment would
   only create a half-context the decoder would later refuse.
5. **`/verify` reads its specimen from `state.extra!`**, so a deep link to that
   route without one would throw. Not reachable in the app today; noted rather
   than fixed, because the fix belongs with route hardening rather than here.

## 13. Tests

| File | Count | Covers |
|---|---|---|
| `test/workflow/work_context_test.dart` | 43 | Identity coherence, provenance invariants, draft→context promotion, readiness, build/validator agreement, context lock, demo configuration |
| `test/workflow/context_persistence_test.dart` | 35 | Round trip at every stage, employee and contractor, all four sites, provenance laundering, every refusal case |
| `test/workflow/work_context_ui_test.dart` | 21 | Form, site inheritance, pickers, manual labelling, readiness gating, lock behaviour, small screen, 200% text |
| `test/workflow/safety_language_test.dart` | 8 | Forbidden authorisation wording, in source and in the readiness vocabulary |
| `test/workflow/persistence_test.dart` | 31 | Pre-existing; clock and storage behaviour, still green |
