# Testing strategy

Tests are weighted by consequence, not by layer. A bug in a button's ripple wastes a second;
a bug in the validity engine produces a confident wrong exposure record on a worker's health
file. The two do not deserve equal attention.

## Tiers

| Tier | Scope | Runner | Gate |
|---|---|---|---|
| T1 Measurement core | `measurement-engine` — all CV, colour, calibration, validity | `dart test`, headless, no Flutter | Every PR. **Blocking.** |
| T2 Database | Drift migrations, constraints, triggers | `dart test` with in-memory SQLite | Every PR. Blocking. |
| T3 Backend | RLS policies, CHECK constraints, triggers | pgTAP against a throwaway Postgres | Every PR. Blocking. |
| T4 Unit / widget | Controllers, repositories, widgets | `flutter test` | Every PR. Blocking. |
| T5 Golden | Design-system components, result states, camera overlay | `flutter test` | Every PR, non-blocking on first failure — goldens need human eyes. |
| T6 Integration | End-to-end workflows on a device/emulator | `integration_test` | Nightly + pre-release. |
| T7 Device matrix | Camera and CV on real hardware | Manual, recorded | Per release candidate. |

## T1 — the one that matters

The measurement core is tested as pure functions over checked-in fixtures. No mocks, because
there is nothing to mock: no clock, no I/O, no network.

Required cases, from directive §26 and dossier §11:

- Known reference image → expected features within tolerance
- Perspective-distorted at several angles → same features after rectification
- Under- and over-exposed → rejection, not a degraded number
- Specular glare over a reference patch → `REFERENCE_PATCH_FAILURE`
- Defocus blur → `POOR_IMAGE`
- Images from different phone models → agreement within tolerance after correction
- One reference patch missing → refusal
- One reference patch damaged/smeared → held-out validation catches it
- Saturated sensor → `SATURATED` with a lower bound, never a capped number
- Blank moved with active → `SENSOR_BLANK_DISAGREEMENT`
- Localised contamination spot → `CONTAMINATION_SUSPECTED`
- Bent badge → rectification residual exceeded → refusal
- Resolution below the geometry's requirement → refusal
- No calibration model for the lot → `UNSUPPORTED_CALIBRATION`
- Model present but `algorithm_version` mismatched → `UNSUPPORTED_CALIBRATION`
- Model checksum invalid → refusal
- Environment outside `environmental_domain` → `ENVIRONMENT_OUTSIDE_VALIDATED_RANGE`

**Property tests** where they are cheap and meaningful: rectification is invariant to the
applied perspective transform; the colour correction is idempotent when input already matches
reference; dose is monotonic in the response feature within the validated range.

**The adversarial test.** A dedicated suite asserts that no input combination produces a
`Valid` result with a null or zero dose, and that no refusal path can be reached with a dose
attached. This is the false-reassurance guard, tested directly rather than assumed from the
type system.

## T2/T3 — constraints are tested, not trusted

The schema's value is in its CHECK constraints, so the constraints get tests that try to
violate them:

- Insert a `poor_image` result with a dose → must fail
- Insert a `valid` result with a null dose → must fail
- Insert a `valid` result with no calibration model → must fail
- UPDATE a result's `dose_ppm_h` → must fail (trigger)
- Insert a `field` result under a `simulated` scan → must fail (trigger)
- Insert `data_domain = 'simulated'` into the production project → must fail (CHECK)
- Two open sessions for one badge → must fail (partial unique index)
- Read another organisation's scans as an authenticated user → must return zero rows
- Read `workers` PII as a safety officer without the identification grant → zero rows
- Worker reads another worker's exposure history → zero rows

Migrations are tested by Drift's migration harness: build schema at version N, apply the
migration, assert the version N+1 shape and that existing rows survived. Every migration, not
just the interesting ones.

## T5 — goldens

Goldens cover the design-system primitives and every result state in both themes, at default
and large text scale, at small and large screen widths. Result-state goldens are the point:
a refusal must never be visually mistakable for a valid reading, and a golden is how that
stays true after six months of styling changes.

## T6 — integration

Full workflows, each with its interruption:

Assign → activate → run → close → scan → result, offline throughout. Then: kill the app
mid-shift and relaunch; sync with the network dropping mid-push; sync the same outbox twice
and assert one server row; scan an expired badge; scan a badge from an unsupported lot; scan
the same badge twice and assert supersession rather than addition; end a shift early and
assert `PARTIAL_SHIFT`; change the device clock mid-shift and assert the coverage warning.

## T7 — device matrix

The camera is part of the instrument, so devices are test subjects, not deployment targets.
One low-end, one mid-range and one high-end Android device, each recorded by exact model in
`devices`. A device that has not been through the matrix is flagged in provenance as
unvalidated, and the result carries that caveat. The app never claims universal Android
compatibility because it launched on a phone.

## What is not tested and why

Simulated data does not validate chemistry, and no test in this repository can. The test suite
proves the software behaves correctly given inputs; only the laboratory programme in dossier
§13 can prove the inputs mean what we think they mean. Test coverage is not evidence of
measurement validity, and the project's claim ledger must never treat it as such.
