# ADR-0005 — Supabase, with separate projects per environment

**Status:** Proposed · 2026-09-19

## Context
Needed: multi-tenant Postgres with row-level authorisation, authentication, private object
storage for evidence images, and a little server-side logic. Directive §17 names Supabase as
the preferred initial candidate to evaluate.

## Decision
Adopt Supabase. Use Postgres, Auth, RLS, Storage and Edge Functions. Do **not** use Realtime.
Run three separate projects: `dev`, `staging`, `prod`.

## Why
- RLS is the natural fit for "organisation isolation from day one" and for the split between
  exposure data and worker identity. Authorisation lives beside the data.
- Auth and private Storage with signed URLs remove two things we would otherwise build.
- Postgres gives the CHECK constraints and triggers the data model depends on.

Realtime is excluded deliberately (directive §17). Nothing in this product needs live push:
a safety officer's exception queue is a pull-to-refresh list, and adding a socket would cost
battery and complexity for no user-visible benefit.

## Why separate projects per environment
It is what makes simulated data structurally incapable of reaching production. The production
project's `data_domain` CHECK admits only `'lab'` and `'field'`; a development build points at
a different project entirely. Combined with compiling simulation out of release builds, there
is no path for a simulated row into a production dataset.

## Consequences
- Three projects to manage, three sets of credentials, none shared with development.
- Migrations are forward-only SQL in `backend/supabase/migrations/`, tested with pgTAP.
- No service-role key ever ships in the client.
