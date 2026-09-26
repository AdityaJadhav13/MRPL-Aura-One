# Session persistence and clock trust

**Status:** implemented (Phase 2). **Scope:** the worker's monitored period only.
Measurement history is a separate, larger problem and lands with Drift in Phase 6.

---

## 1. What this exists for

A passive dosimeter badge integrates exposure over the whole time it is worn. The
app does not measure continuously — it records *when the period started* and
*when it ended*, and the badge does the rest. That makes the start and end
timestamps part of the measurement, not UI state.

Before this change, those timestamps lived in memory. A worker who began a
monitored period at 06:10 and whose phone was killed at 09:40 — by an OS
memory reclaim, an update, a flat battery, or a drop — came back to an empty
home screen. The badge on their chest was still integrating; the app had
forgotten it existed.

So: every workflow transition is written to durable storage before the UI
advances, and the period is read back at launch.

## 2. The seam

```
ShiftSessionController  ──►  WorkflowStore (interface)
                                  ├── InMemoryWorkflowStore   (tests)
                                  └── FileWorkflowStore       (the app)
                                          └── SessionCodec
```

`WorkflowStore` was already the narrow seam. This phase adds a real
implementation behind it and a codec beside it; the controller and every screen
are unchanged.

### Why a file, not SQLite

A session is **one small record**, written on each transition and read once at
launch. Phase 6 brings Drift for the *measurement history* — a growing,
queryable, syncable table, which is a different problem with different
requirements. One record does not need a database, and `path_provider` was
already a dependency, so this adds none.

The snapshot lives at `getApplicationSupportDirectory()/shift_session.json`.
Not a cache directory, which the OS may reclaim — reclaiming it is exactly the
event we are defending against. Not external storage, which other applications
can read.

### Writes are atomic

`save` writes a sibling `.tmp` file, flushes it, then renames it over the
target. `rename` within a directory is atomic on both platforms' native
filesystems, so a process killed mid-write leaves either the previous snapshot
or the new one — never half of either.

This is not theoretical tidiness. The app is killed *precisely* in the
situations this store exists to survive, so the write has to be safe under a
kill at any instant.

## 3. Decoding refuses; it never repairs

`SessionCodec.decode` returns null — and the store falls back to
`ShiftSession.none` — whenever the stored value is not something it can
reconstruct faithfully:

| Discarded | Why |
|---|---|
| A different `schema` | Nothing has been released, so there is no version to migrate *from*. A migration path would be speculative code for a case that has never existed. |
| Malformed or truncated JSON | |
| An unparseable timestamp | A guessed start time is a guessed exposure window. |
| An unknown stage, permit confirmation, status or censor direction | |
| A `badge_id` the catalogue no longer offers | The specimen would have to be invented. |
| A stage missing what it requires (monitoring with no start, complete with no result, …) | The workflow could not have written it. |
| A stage carrying evidence of a later one | Same. |
| A stored `Valid` whose provenance has no calibration model | A dose without a model behind it is not a measurement. |
| A stored dose under a refusal or censored status | The `dose_only_when_valid` invariant, enforced on the way *in* as well as out. |
| A negative dose, bound or coverage | |

A partially reconstructed session is worse than none. It would put a worker back
into a period whose badge, stage or start time is a guess — and every one of
those feeds a number. The fallback, an empty session, is honest: it says the
period was lost, and they start again.

This is the same rule the measurement pipeline follows, applied to storage:
**refuse rather than guess.**

### Badges are stored by identity

Only `badge_id` is written; the specimen is re-resolved from the catalogue on
load. Copying a badge's lot, expiry and declared outcome into the snapshot would
let a stale duplicate outlive its source. This is also what the Phase 6
implementation will do, with the database in place of the catalogue.

### Coverage is stored in microseconds

`Duration`'s own resolution. Storing whole seconds would mean a restored result
differed from the one that was computed — physically negligible, but a
measurement record that changes when it is reloaded is not traceable.

## 4. Clock trust

Persistence introduces a problem that in-memory state did not have: **between
writing a start time and reading it back, the device clock can move.**

An Android device without a battery-backed RTC can boot with a wrong clock and
correct it over NTP seconds later. A user can change the time or the timezone. A
reboot can land anywhere.

This matters more here than in most apps, because exposure duration multiplies
directly into ppm·h. A four-hour exposure reported over a twelve-hour window is
not a rounding error; it is a wrong number that looks entirely plausible.

### What is detected

A window that runs **backwards** — `endedAt` before `startedAt`, or "now"
before `startedAt` — is proof that the clock moved, because time does not run
backwards. `ShiftSession.coverageAt` returns **null** in that case.

It used to clamp the negative difference to `Duration.zero`, which printed
"0 h 00 min" for a period that had genuinely been running for hours. That is a
plausible number standing in for an unknown one, which is the single failure
mode this project exists to avoid.

Consequences, all tested:

- The active-monitoring, end-monitoring and home screens print `- - -`
  (`Fmt.noValue`) instead of a duration.
- `completeScan` returns **`Refused`** with status `resultUnreliable` and the
  reason `EXPOSURE_WINDOW_UNTRUSTED`, instead of `Valid`. This is the one place
  a specimen's declared outcome is overridden, and it can only ever be
  overridden *towards* a refusal.
- That refusal carries **no** `calibrationModelId`, so nothing implies a dose
  was computed.

### What is NOT detected, and is not claimed to be

**A forward jump is invisible.** If the clock jumps from 08:00 to 14:00 while
monitoring is active, the window looks like six hours of ordinary elapsed time
and nothing in the stored data contradicts it.

Distinguishing a forward jump from time actually passing needs a clock that
cannot be set — Android's `SystemClock.elapsedRealtime()`, iOS's
`CLOCK_MONOTONIC` — recorded alongside the wall clock at every write. That is a
platform channel on both sides, and it cannot be verified without a physical
device, which this project does not currently have (see M0C).

**This is an open gap, not a solved problem.** It is recorded here so that the
partial protection above is not mistaken for full clock integrity, and it is
carried in `PROJECT_STATE.md` as remaining Phase 2 work.

### A backwards window is kept, not deleted

The codec deliberately does **not** reject a snapshot whose end precedes its
start. That state is real: the worker's period happened and the badge is still
on them. Rejecting it at decode would delete the period and hide the problem.
Keeping it lets the duration refuse, the screens print `- - -`, and the scan
return a refusal that says what went wrong.

Refuse loudly; do not discard quietly.

## 5. Failure to open the store

If the store cannot be opened at all — a full or read-only filesystem —
`bootstrap` falls back to `InMemoryWorkflowStore` and logs. The app still runs
the monitored period and only loses it on a cold start, which is no worse than
the behaviour before persistence existed. It must not be a launch failure: a
worker at the gate with a badge needs the app to open.

## 6. Tests

`app/test/workflow/persistence_test.dart` — 31 tests.

- Round-trip at **every** `ShiftStage`, through real file IO in a temp directory.
- Round-trip of **every** specimen in the catalogue, covering each
  `MeasurementResult` variant, asserting dose, coverage, bound, direction,
  reasons and provenance survive.
- Rejection: truncated file, foreign schema, unknown badge, missing and
  contradictory stage evidence, unparseable timestamp, unknown enum, non-map.
- Dose integrity on the way in: no calibration model, dose under a refusal
  status, negative coverage.
- Clock: backwards window yields null coverage; not-started yields null; a
  just-opened window yields zero (which is a measurement, not an absence);
  `Fmt.duration(null)` prints the refusal placeholder; a scan over an
  untrustworthy window refuses; the same specimen over a good window still
  reports its dose.

The last pair matters most: it pins down that the refusal is caused by the
untrustworthy window and not by the specimen, so the guard cannot silently
start refusing everything.
