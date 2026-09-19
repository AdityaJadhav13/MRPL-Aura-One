# ADR-0006 — Data domain (simulated / lab / field) is a schema-level concept

**Status:** Proposed · 2026-09-19

## Context
Directive §2 requires hard separation of simulation, laboratory calibration and field data,
and forbids simulated values silently entering calibration or production datasets. Directive
§25 requires a simulation mode, because development must proceed before chemistry exists.

## Decision
`data_domain` is a NOT NULL enum column on every measurement-bearing table, not a runtime flag
and not a UI mode.

Four enforcement layers:
1. **Type.** Domain is carried on the row from session → scan → features → result.
2. **Trigger.** A child row's domain must equal its parent's. Checked in the database.
3. **Calibration gate.** `calibration_models.permitted_domains` controls which domains a model
   may be applied in.
4. **Environment.** Production Supabase CHECKs the enum down to `('lab','field')`;
   simulation is compiled out of release builds.

## Why not a boolean flag
A flag can be forgotten, defaulted, or lost when a record is copied. A NOT NULL column with a
propagation trigger cannot be. The directive's requirement is that simulated values never
*silently* enter production data — the operative word is "silently", and only a constraint
delivers loudness.

## User-visible consequence
Anything in the `simulated` domain carries a persistent, non-dismissible marker reading
**SIMULATED — NOT A REAL H₂S MEASUREMENT**, on screen and in every export. Not a subtle badge.

## Note on the middle domain
`lab` covers two different things that are both legitimately non-field: optically-validated
printed-target work (dossier V0) and gas-exposed coupons (V1–V7). They share a domain because
both are controlled, traceable and permitted to inform calibration; they are distinguished by
the experiment identifier on the record, not by a separate domain.
