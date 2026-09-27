# Lifecycles and status axes

Five axes, each with its own vocabulary and its own chip in the UI. Example
that must be representable, and is: DoseBand **read** · session **read
complete** · measurement **No Reading — no calibration** · review **awaiting
review** · sync **saved on this device**.

## DoseBand lifecycle (`DoseBandLifecyclePolicy`)

```
available → assigned → monitoring → readyForFinalRead → read → reviewed → disposed
exceptional: damaged · lost · invalid · expired · assignmentCancelled · readFailed · missingFinalRead
```

Nothing returns to `available`. Inventory buckets (`InventoryBucket`) are
mutually exclusive, so lot counts add up; an unused band from an expired lot
counts as expired. Administration cannot change a band that is in an open
monitoring period.

## Monitoring session (`MonitoringSessionPolicy`)

```
notStarted → active → readyForFinalRead → readComplete → reviewed → closed
notStarted → closed                      (assignment cancelled before start)
active → interrupted                     (band reported damaged/lost)
readyForFinalRead → finalReadMissing     (closed out; no reading inferred)
```

`partial`, `bandReplaced`, `invalidRead` exist in the policy; this build
produces `interrupted` for a replaced band (the replacement is a new period).

## Measurement

`ResultStatus` from the engine, unchanged. Worded by
`MeasurementStateText`; no non-valued state can render or export as a
number. Records are append-only: a second record for a period is refused
unless it names the first in `supersedesId` with a reason, and both are kept.

## HSE review (`ReviewPolicy`)

```
pending → inReview → { infoRequired → inReview } → reviewed → closed
```

A disposition (no further action · repeat monitoring · investigate work area ·
refer under the site occupational-health procedure) is recorded once
reviewed. Reviews never touch the record.

## Sync

`SyncState.localOnly` for every record in this build; `syncPending`,
`synced`, `syncFailed` are declared and never produced.

## Worker day (`DayStatus`)

Derived for supervisor and management counts, one status per worker:
not started · DoseBand claimed · monitoring · final scan due · completed ·
needs attention. A period left open from an earlier day is *needs attention*.
