# backend

The server side of DoseBand. Today this is the database contract only; no server is
deployed, and the app runs entirely on-device.

```
supabase/
├── migrations/   PostgreSQL schema, including the measurement-result invariants
└── tests/        pgTAP suite and a plain-SQL invariant check (run in CI)
```

The invariant that matters most: a result that is not valid **cannot** carry a dose. It is a
`CHECK` constraint, not an application convention, so no client — correct or not — can
write one.

Run the checks against a local PostgreSQL:

```bash
createdb doseband
for m in supabase/migrations/*.sql; do psql -d doseband -v ON_ERROR_STOP=1 -f "$m"; done
psql -d doseband -v ON_ERROR_STOP=1 -f supabase/tests/verify_invariants_plain.sql
```

Not built yet: authentication, row-level security for live data, sync, and server-side
authorisation. The app marks all of them as not connected.
