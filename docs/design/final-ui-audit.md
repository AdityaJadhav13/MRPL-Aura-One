# UI-SURFACE-01 — final audit defect register

Phase **UI-SURFACE-01-FINAL-AUDIT**, 2026-09-25.
Flutter 3.47.5 · iPhone 16 Pro simulator (iOS 18.6) · 662 app tests.

The application was reviewed horizontally — one product, not six modules — for
inconsistency, drift, misleading affordance and unsupported claim. This is the
full list of what was found. Nothing found is omitted; deferred items carry a
rationale.

---

## FIXED

### F-01 — Twelve detail routes crashed when deep-linked · **HIGH**

**Screen/component:** `app/lib/core/router/app_router.dart`, twelve routes.

**Problem:** Detail routes took their subject from `GoRouterState.extra` and
wrote `state.extra! as T`. `extra` travels with the navigation call, not in the
URL, so it is null on a typed address, a deep link, a cold-start restore of the
last location, and a browser back on web. Every one of those threw an uncaught
cast exception.

**Root cause:** The force-unwrap was written once and copied eleven times. There
was no shared route-building helper, so each new detail route reintroduced it.

**Fix:** A single generic `_needs<T>()` guard in the router, plus a shared
`MissingRouteContextScreen` that states what the screen needs, why the link did
not carry it, and offers a route back to the list it came from. No route
force-unwraps `extra` any more.

**Verification:** `test/surface/route_integrity_test.dart` opens all twelve
routes without `extra`, asserts no exception, asserts the explanation renders,
and taps the recovery action to confirm it leads somewhere real.

---

### F-02 — Loop-based UI tests only ever exercised their first route · **HIGH**

**Screen/component:** 18 test files.

**Problem:** Every test that pumped `DoseBandApp` more than once inside one
`testWidgets` body was testing a single route repeatedly under many names.
`DoseBandApp` builds its `GoRouter` once; pumping the same widget type with a
different `initialLocation` reuses the existing `State`, so the route never
changed. A test that looped 20 routes asserted 20 times against route one.

**Root cause:** `initialLocation` is only read at router construction, and
nothing forced a new `State`.

**Fix:** Every pump now passes `key: ValueKey(route)`, which forces a fresh
`State` and a fresh router per route.

**Verification:** Applying the key turned 641 passing tests into 641 passing and
**21 failing** — coverage that had been illusory. Every one of those failures is
recorded below as its own defect (F-03 to F-07). This is the most consequential
finding of the audit: a meaningful share of the honesty coverage was not running.

---

### F-03 — Emphasis cards used corporate green on statements of absence · **MEDIUM**

**Screen/component:** `InfoCard(emphasis: true)` — shared, 4 sites.

**Problem:** The emphasis edge reused `selectedBorder`, a saturated MRPL green.
Three of the four emphasised cards in the product state an *absence*: "No
production H₂S calibration available", "No production calibration available",
and a device's untested validation state. A green edge around those reads as
approval of the sentence it surrounds — in a safety product, where green
conventionally means safe or cleared.

**Root cause:** Two different concepts shared one token. "Selected" is a state
the user put a card into; "emphasised" is the author saying read this first.

**Fix:** A dedicated `MrplCorporateColors.emphasisBorder` — neutral ink, at
`Borders.emphasis` width. Emphasis is now carried by weight and contrast, which
says nothing about whether the news is good. `selectedBorder` keeps its green
for genuine selection.

**Verification:** Goldens regenerated for all four screens; confirmed on device
in `screenshots/product/18-admin-calibration.png`.

---

### F-04 — The worker's primary CTA was below the gloved touch minimum · **MEDIUM**

**Screen/component:** `AuthPrimaryButton` (shared, every corporate screen) and
`HomeScreen`'s contextual action.

**Problem:** `kMinTouchTarget` is 56 — larger than Material's 48 specifically
because the user may be gloved and a mis-tap during badge closure corrupts a
coverage record. Both buttons hard-coded `54`, and `AuthPrimaryButton` is *the*
primary action on every corporate screen, so the shortfall was product-wide.

**Fix:** Both now use the token. `MissingRouteContextScreen`'s recovery action
(introduced by F-01, and initially 48) was corrected at the same time.

**Verification:** `test/surface/responsive_test.dart` measures every enabled
`FilledButton` on the priority screens against `kMinTouchTarget`.

---

### F-05 — No screen exposed its title as a heading · **MEDIUM**

**Screen/component:** all 74 routes.

**Problem:** Titles were styled as headings through the type scale but carried
no `header` semantics flag. A sighted user gets the hierarchy from the type; a
screen-reader user gets it only from the flag, and without it there is no way to
jump to the top of a screen or tell a title from body text.

**Fix:** The flag set once in each of the three shared scaffolds —
`SafetyScaffold` (68 routes), `StepScaffold`, `AuthScaffold` — plus the four
screens that render their own title (`SignInScreen`, `HomeHero`,
`GuidedScanScreen`, and the sign-in header).

**Deliberate exemption:** `/splash` carries branding rather than content,
advances on its own and has no title to navigate to. A heading there would be a
flag added to satisfy a test. The exemption is written into the test.

**Verification:** `test/surface/responsive_test.dart` asserts a header on every
route except `/splash`.

---

### F-06 — Status pills overflowed rows by 99px at 200% text · **MEDIUM**

**Screen/component:** `/reporting/register`, `/hse`, `/hse/exposures` — three
record-card headers.

**Problem:** `Row(Expanded(name), StatusPill(...))`. A rigid pill beside an
`Expanded` has no width to give back, so at 200% text the row ran 99 pixels past
the card edge. The same pattern had already been fixed once on the Admin
overview during the previous phase, which is how it was recognised.

**Fix:** Both children made flexible, so the status label wraps rather than
truncating. A half-shown monitoring state is worse than a two-line one.

**Verification:** `test/surface/responsive_test.dart` renders the 20 priority
screens at 200% text, and again at 200% text under a notch.

---

### F-07 — The report builder showed simulated figures without the standing banner · **LOW**

**Screen/component:** `/reporting/preview` (reached from the builder).

**Problem:** The screen renders `ExposureCell` quantities but the assertion that
covered it had been passing vacuously under F-02. Investigation showed the
builder itself shows no figures — so the original test was wrong about which
screen needed the banner, and the preview and traceability screens were the ones
to check.

**Fix:** The test now asserts the banner on the three screens that actually put
a quantity on the page, and reaches the record by tapping through the register
rather than by URL (those routes carry their subject in `extra`).

**Verification:** `test/reporting/reporting_surface_test.dart`.

---

### F-08 — A build-mode banner used the simulated-measurement magenta · **LOW**

**Screen/component:** `/admin/demo-data`.

**Problem:** The "Development build only" banner was styled with
`statusSimulated`. That magenta is reserved so it means exactly one thing
wherever it appears: *this quantity is not a real H₂S measurement*. The banner
is about which build is running, not about measurement provenance.

**Fix:** Re-styled as a neutral emphasis card with a construction icon.

---

### F-09 — "Not available" competed with "Unavailable" · **LOW**

**Screen/component:** `/hse/worker`.

**Problem:** One site used "Not available" where 46 others used "Unavailable"
for the same meaning — data that cannot currently be provided.

**Fix:** Normalised to "Unavailable". The three-way distinction the product does
keep — **Not connected** (integration exists conceptually, no live connection),
**Not configured** (an organisation value is expected and absent), **Unavailable**
(evidence or function cannot be provided) — is intact and was left alone.

---

### F-10 — Prohibited-claim lists had diverged across eight test files · **MEDIUM**

**Screen/component:** test suite.

**Problem:** Eight module test files each grew their own forbidden-phrase list.
Each was right for its module, which is the problem: a phrase added to the HSE
list did not protect the Reporting screens, so a claim could appear on whichever
surface had the shorter list.

**Fix:** `test/support/prohibited_claims.dart` holds the full vocabulary —
safety, regulatory, security, calibration, maturity and zero-collapse claims —
and `test/surface/claims_test.dart` sweeps it over all 74 routes. Module tests
keep their own lists, which carry reasoning worth reading at the point of use,
but nothing now depends on those lists being complete.

**Note on the matcher:** a naive substring search was wrong in the direction
that matters. DoseBand's screens are full of sentences like "No validated
calibration model exists" that contain a forbidden phrase precisely to refute
it; flagging those would push an author toward deleting the denial. `assertsClaim`
ignores a match governed by a negator, and the test asserts the matcher both
fires on a real claim and stays silent on a denial.

---

## DEFERRED

### D-01 — "Monitored period" and "monitoring window" coexist

**Severity:** informational. 28 uses of the former, 5 of the latter.

**Rationale for deferring:** These are arguably distinct — "monitored period" is
the assigned period a worker is covered for; "monitoring window" is the field
name in the traceability chain, and the phase directive itself uses "Monitoring
Window" for that link. Renaming 28 user-facing strings to collapse a distinction
that may be real is a worse outcome than the inconsistency. Worth a decision
when the occupational record schema is formalised, not during a freeze.

### D-02 — Three site photographs outstanding

**Severity:** content, not UI.

**Rationale:** The image slots, aspect ratios, crop behaviour, overlay
readability and fallback state were all audited and hold. The photographs
themselves have not been supplied. Per §36 this is explicitly not a freeze
blocker; it is a post-freeze content task.

### D-03 — `app/build` at 640 MB

**Severity:** housekeeping.

**Rationale:** Regenerable simulator build output, retained because further
capture runs were expected during the audit. Safe to delete; deliberately not
deleted automatically.

---

## Audited and found clean

These were examined and produced no defect. Recorded so a later reviewer knows
they were looked at rather than skipped.

| Area | Result |
|---|---|
| Safety language (§27) | Clean. The only matches are the 13 sites that state what DoseBand is *not*. |
| Regulatory language (§26) | Clean. "OISD-aligned"/"DGMS-aligned" with caveats; no compliance claim. |
| Security language (§28) | Clean. No encryption, certification or maturity claim anywhere. |
| Status colour (§11) | Clean by construction: `statusValid` is cyan, commented "deliberately **not green** — green means safe, and this badge cannot tell anyone they are safe". `statusRefused` is neutral ink, not alarm red. |
| Corporate/instrument register (§10) | Clean. No corporate colour on a measurement surface. The two instrument tokens on corporate surfaces are correct: the simulated marker on a quantity, and a black viewfinder ground behind a capture image. |
| Icon consistency (§41) | Clean. 38 navigation rows, zero titles with divergent icons. |
| Terminology (§42) | Clean. "Patch" is always "reference patch", a distinct measurement concept, never a synonym for badge. |
| Calibration metrics (§25) | Clean. The only numeric bounds are `_simLoq`/`_simSaturation`, commented as simulated scale limits, plus dev-only gallery specimens. |
| Zero-collapse (§22, §23) | Clean. No hard-coded zero dose; `Fmt.noValue` is the single source for absence. |
| Export honesty | Clean. Every export string is a negation. |
| Cross-language parity | 394 comparisons, all matching. |
| Geometry drift | 75 tests passing. |
