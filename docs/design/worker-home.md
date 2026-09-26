# Worker Home

**Phase:** UI-SURFACE-01 corrective rebuild · **Updated:** 2026-09-25

## Why this was rebuilt

The previous Home was a title, a large blank area, the sentence "No active
monitored shift", and one button. It was not a dashboard — it was an empty
state that happened to be the default screen.

Two problems, and the second is the serious one:

1. It looked unfinished, which is a presentation failure.
2. **It taught the worker nothing.** A worker who opens DoseBand before their
   shift should be able to see what a monitored period requires and which parts
   are outstanding. A blank screen says only that the app has nothing, which is
   the least useful true statement available.

## One architecture, nine states

The section order never changes:

```
HERO  ·  MRPL + DoseBand identity over refinery imagery
IDENTITY  ·  worker card, overlapping the hero
TODAY'S SHIFT  ·  site, department, shift, work area, gate pass, date
WORK CONTEXT  ·  PTW, JSA, toolbox talk, supervisor
MONITORING  ·  the operational card
PRIMARY ACTION  ·  one orange button
STATUS STRIP  ·  one line about DoseBand's workflow state
QUICK ACTIONS  ·  work context · safety · history · emergency
```

Only the **content** and the **offered action** change between states. A
worker checks this screen in gloves, in daylight, between tasks; if the layout
reorganises itself between "no shift" and "monitoring active" there is no
stable place to look.

`HomePresentation.from()` derives everything in one place, so the monitoring
card, the button and the strip cannot contradict each other. Three widgets each
deciding for themselves is how a screen ends up saying "Not started" above a
button that says "End monitoring".

## State matrix

| # | Stage | Monitoring card | Primary action | Status strip |
|---|---|---|---|---|
| **HOME-01** | `noShift` | Not started · badge not assigned | **Start work context** → `/work-context` | Record your work context before a DoseBand can be assigned. |
| **HOME-02** | `contextSet`, validator not satisfied | Not started | **Complete work context** → `/work-context` | Work context is incomplete. Finish it before assigning a DoseBand. |
| **HOME-03** | `contextSet`, complete | Badge not assigned | **Assign DoseBand** → `/assign` | Work context recorded. Assign the DoseBand you have been issued. |
| **HOME-04/05** | `badgeAssigned` | Ready for pre-work check | **Pre-work check** → `/prework` | DoseBand assigned. Complete the pre-work dosimetry check. |
| **HOME-06** | `readyForDosimetry` | Ready for dosimetry | **Start monitoring** → `/prework` | Ready for dosimetry. This confirms DoseBand has what it needs — it does not authorise work. |
| **HOME-07** | `monitoring` | **MONITORING ACTIVE** · duration · started · badge · ACTIVE | **End monitoring** → `/end` | Monitoring active. The DoseBand is recording cumulative exposure and cannot warn you about anything. |
| **HOME-08** | `awaitingScan` | Awaiting badge scan | **Scan DoseBand** → `/read` | Monitoring ended. Scan the badge to produce a reading. |
| **HOME-09** | `complete` | Reading complete | **Start new work context** → `/work-context` | Reading complete. Start a new work context when issued your next DoseBand. |
| **HOME-10** | any stage, window untrusted | **Duration not trustworthy** · `- - -` · warning | **End monitoring and read badge** → `/end` | The monitored period cannot be timed. End the period and read the badge — the exposure window will be reported as unknown. |

**HOME-10 outranks the stage.** A worker whose device clock moved needs to know
that *before* they are told how long they have been monitoring, because the
honest answer to that question is "we cannot say".

Every `actionRoute` is one the workflow genuinely permits from that stage — a
test asserts this. Home never offers a shortcut the controller would refuse.

## Empty values, not an empty screen

A missing field renders `Not provided` or `Not selected`. The section stays.

```
TODAY'S SHIFT
Site          Not provided     Department    Not provided
Shift         Not provided     Work area     Not selected
Gate pass     Not provided     Date          25 Sep 2026
```

This is a product rule, not a layout convenience: the worker keeps the whole
mental model of what a monitored period needs.

## Where each field comes from

| Field | Source |
|---|---|
| Worker name, ID, type, contractor | `session.context.worker` — the snapshot taken when the context was committed |
| Site, department, shift, work area | `session.context` |
| Gate pass | `session.context.worker.gatePass`, masked to the last four |
| Date | Device date |
| PTW, JSA, toolbox talk, supervisor | `session.context`, each with its `EnterpriseDataSource` tag |
| Duration | `session.coverageAt(now)` — the trusted clock, nullable |
| Badge ID | `session.badge` |
| Recent records | `historyProvider` |
| Connectivity | **Constant: "Local · Not synced"** |

Nothing on Home is invented, and Home holds no state of its own.

### Connectivity is not faked

The card says **Local · Not synced**, never "Online". DoseBand has no backend;
there is nothing to be online *to*. Every app has a connectivity dot, which
makes it the easiest fake on the screen and the one a reviewer is most likely
to accept without checking.

## Colour

The monitoring card is MRPL green because it is the product's primary surface —
**not** because anything is safe. Green is identity here and never status. The
card carries no word like "safe", "normal" or "clear", and a valid reading
would mean the instrument trusts the measurement, not that the exposure was
acceptable.

The single orange control is the primary action. A second orange button would
cost exactly what the first one buys: the answer to "what do I do next?" in
under a second. Emergency in Quick Actions carries the accent too, because it
is a route to information — red stays destructive-only in this system.

Bottom navigation is deep refinery green with an orange selection, via
`CorporateNavigationTheme(onDark: true)`. The HSE, Reporting and Admin shells
keep the light bar: they are used for longer stretches at a desk, and a dark bar
under a long scrolling table reads as a floor rather than a control.

## Account

Reached by tapping the worker's own identity card, labelled
`Account and profile` for screen readers. It is not a fourth bottom-bar
destination and not a floating icon in an app bar — the four worker
destinations are Home, Scan, Safety, History, and that is a hard limit.

## Responsive behaviour

* Hero height scales with the text setting, `200–310` logical pixels.
* Today's Shift drops to one column below 280 px or above 1.4× text.
* The monitoring card stacks its two columns below 300 px or above 1.3× text.
* Quick Actions are 2 columns on a phone, 4 at ≥560 px.
* The duration uses `FittedBox` rather than clipping — "3 h 42 min" truncating
  to "3 h 42" would silently change a measured quantity.
* Verified at 360, 390 and 430 px wide, and at 200% text.

## Persistence

Home is a projection of `shiftSessionProvider`, which is restored from
`FileWorkflowStore` at launch. A worker who starts monitoring, has the app
killed, and reopens it lands on **HOME-07 MONITORING ACTIVE** with the same
badge and start time — asserted by a test.

## Tests

| File | Covers |
|---|---|
| `test/home/home_states_test.dart` | The projection for all ten states, CTA per stage, untrusted clock, restored session, honest connectivity, no safety claims, 360/390/430 and 200% text |
| `test/golden/home_states_golden_test.dart` | Visual review artefact: one image per state at 390×1500 |
| `test/surface/surface_navigation_test.dart` | Four destinations only, account reachable from the identity card |

The live-monitoring state has **no pixel golden**: its elapsed clock ticks, so
the image would change every minute and the test would fail on a schedule
rather than on a regression. Its duration is asserted in the widget tests
instead.
