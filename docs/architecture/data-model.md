# Data and domain model

The same schema exists twice: in Postgres (Supabase, authoritative, RLS-protected) and in
SQLite (Drift, local, offline source of truth). The local schema is a subset — it omits
other workers' data and carries the outbox and cache tables the server does not need.

Constraints are written in the database. Application-level validation is a UX convenience; it
is not where correctness lives.

## Universal columns

Every table: `id uuid pk`, `created_at timestamptz not null default now()`,
`updated_at timestamptz not null`, `created_by uuid`. Tenant tables additionally carry
`org_id uuid not null`. Deletion is soft (`deleted_at`) only for organisational records —
never for scans, features, results or audit rows, which are immutable.

## Data domain — the separation that must not leak

```sql
create type data_domain as enum ('simulated', 'lab', 'field');
```

`data_domain` is NOT NULL on `exposure_sessions`, `scans`, `optical_features`,
`measurement_results` and `environmental_records`. Three mechanisms keep the domains apart:

1. **Propagation, checked.** A scan inherits the session's domain; a result inherits the
   scan's. Enforced by a trigger comparing parent and child, not by application code.
2. **Calibration gating.** `calibration_models.permitted_domains` lists which domains a model
   may be applied in. A simulated model cannot be used to compute a field result, and a
   validated field model is not consumed by simulation runs.
3. **Environment separation.** Dev, staging and production are separate Supabase projects. The
   production project's CHECK admits only `'lab'` and `'field'`. Simulated data is not merely
   discouraged from reaching production — it has nowhere to go.

Combined with `simulation_mode` being compiled out of release builds, simulated data entering
a production dataset requires defeating a compile-time exclusion, a project boundary and a
database constraint.

## Identity and organisation

```
organizations ─┬─ sites ─── departments ─── workers
               └─ users ─── user_roles
```

| Table | Notes |
|---|---|
| `organizations` | Tenant root. |
| `sites`, `departments` | Hierarchy per directive §17. |
| `users` | Auth account. Maps to `auth.users`. |
| `roles` | `worker`, `safety_officer`, `supervisor`, `admin`, plus later `lab_engineer`, `org_admin`. |
| `user_roles` | Many-to-many, scoped to org and optionally to site. A user may be an officer at one site and nothing at another. |
| `workers` | **Carries `worker_token` (opaque, unique) and the PII.** Exposure tables reference the token, never this row's identity fields. |

`workers` has its own RLS policy, deliberately stricter than the exposure tables. A safety
officer can read every exception in their site; identifying who it belongs to is a separate
grant. This is directive §3's "workers must not automatically have administrative access"
applied symmetrically — officers do not automatically get identification either.

## Badge and calibration

| Table | Key fields |
|---|---|
| `formulations` | `code`, `version`, chemistry route, status. The chemistry identity. |
| `badge_geometries` | `version`, `roi_definition jsonb` — ROI coordinates in badge millimetre space, fiducial positions, patch layout. **Geometry is data.** No ROI coordinate appears in Dart source. |
| `badge_batches` | `lot_code`, `formulation_id`, `geometry_id`, manufactured_at, `use_by`, `status` (`released`, `quarantined`, `withdrawn`), `permitted_use`. |
| `badges` | `badge_id`, `batch_id`, `state` (`stock`, `assigned`, `activated`, `closed`, `read`, `voided`), `activated_at`, `closed_at`. Single-use lifecycle. |
| `reference_profiles` | `print_lot`, `patch_values jsonb` (**measured**, not nominal), `fit_patch_ids`, `holdout_patch_ids`, `max_delta_e`. |
| `calibration_models` | See below. |

```sql
create table calibration_models (
  id uuid primary key,
  version text not null,
  batch_id uuid references badge_batches(id),   -- null = applies to a formulation family
  formulation_version text not null,
  geometry_version text not null,
  reference_profile_id uuid not null,
  algorithm_version text not null,              -- which pipeline code this was fitted against
  feature_definition jsonb not null,            -- which features, how computed
  parameters jsonb not null,                    -- LUT / monotonic fit coefficients
  validated_range jsonb not null,               -- loq, saturation, upper bound
  environmental_domain jsonb not null,          -- validated T / RH / airflow envelope
  uncertainty_model jsonb not null,
  permitted_domains data_domain[] not null,
  valid_from timestamptz not null,
  valid_until timestamptz,
  checksum text not null,
  signature text,                               -- signed by the calibration authority
  unique (version, batch_id)
);
```

The client verifies `checksum` before use and refuses a model that fails. `algorithm_version`
matters more than it looks: a calibration fitted against pipeline v3 must not be applied by
pipeline v4 if feature extraction changed. Mismatch produces `UNSUPPORTED_CALIBRATION`, not a
best-effort reading.

## Shift, assignment, session

| Table | Notes |
|---|---|
| `shifts` | Site, department, planned start/end, shift code. |
| `badge_assignments` | Badge ↔ worker token ↔ shift, `wearing_location` (`wrist`, `collar`, `other`), issued_by, issued_at. |
| `exposure_sessions` | The measurement window. `started_at`, `ended_at`, plus `device_clock_start`, `monotonic_start`, `device_clock_end`, `monotonic_end`, `server_time_at_sync` for the clock-integrity check. `coverage_status` (`complete`, `partial`, `unknown`). `data_domain`. |

A partial unique index enforces one open session per badge and one open session per worker
token, which is what actually prevents a double-start after a device change.

## Scan and result

| Table | Notes |
|---|---|
| `scans` | `session_id`, `captured_at`, `image_hash`, `image_storage_path`, `device_id`, `app_version`, `algorithm_version`, `entry_method` (`qr`, `manual`), `data_domain`. Immutable. |
| `scan_quality` | Blur, exposure, clipping fractions, glare score, resolution, fiducial confidence, rectification residual, colour-correction ΔE₀₀ on held-out patches. |
| `optical_features` | Per-ROI robust statistics in CIELAB and linear RGB, spatial gradient, reacted-area fraction, front length. Stored so a result can be *recomputed* later from features without the original image. |
| `validity_checks` | One row per check run, with code, outcome and detail. This is why the app can explain a refusal. |
| `measurement_results` | See below. |
| `environmental_records` | Source, coverage, history or explicitly unknown. Never inferred from a weather API and never silently defaulted. |

```sql
create table measurement_results (
  id uuid primary key,
  scan_id uuid not null references scans(id),
  status result_status not null,
  dose_ppm_h numeric,
  uncertainty_ppm_h numeric,
  coverage_interpretation text,
  bound_ppm_h numeric,               -- one-sided bound for censored states
  bound_direction text,              -- 'lower' | 'upper'
  calibration_model_id uuid references calibration_models(id),
  algorithm_version text not null,
  data_domain data_domain not null,
  supersedes_result_id uuid references measurement_results(id),
  superseded_at timestamptz,

  -- A failure is never a number.
  constraint dose_only_when_valid check (
    (status in ('valid','valid_with_warning')) = (dose_ppm_h is not null)
  ),
  constraint uncertainty_accompanies_dose check (
    (dose_ppm_h is null) or (uncertainty_ppm_h is not null)
  ),
  constraint bound_only_when_censored check (
    (status in ('below_quantification_limit','above_range','saturated'))
    or (bound_ppm_h is null)
  ),
  constraint valid_requires_model check (
    (status not in ('valid','valid_with_warning')) or (calibration_model_id is not null)
  )
);
```

`dose_only_when_valid` is the most important line in the schema. It makes "convert a failure
into 0 ppm·h" unrepresentable, and it makes "report a dose with no calibration model behind
it" unrepresentable. Both would otherwise be one careless null-coalescing operator away.

Results are insert-only. A recalculation inserts a new row with `supersedes_result_id` set and
stamps `superseded_at` on the old row; the old row's values are never touched. A trigger
rejects any UPDATE to a result's measurement fields.

## Result status enum

```
valid · valid_with_warning · below_quantification_limit · above_range · saturated ·
poor_image · badge_expired · badge_damaged · badge_already_used · unsupported_batch ·
unsupported_calibration · reference_patch_failure · blank_failure ·
sensor_blank_disagreement · partial_shift · environment_outside_validated_range ·
contamination_suspected · result_unreliable
```

`sync_pending` is deliberately **not** in this enum. Sync state is a property of the row's
transport, not of the measurement, and conflating the two would let a network problem look
like a measurement problem. It lives in `sync_state` on the outbox.

## Operational tables

`devices` (model, OS, first seen, validation tier — the camera is part of the instrument, so
the device model is measurement metadata), `app_versions`, `alerts`, `reviews`,
`audit_events` (append-only), `outbox` (local only: `mutation`, `payload`, `idempotency_key`,
`attempts`, `next_attempt_at`, `last_error`).

## History classification

History never shows a flat list of numbers. Each entry carries its class — valid, valid with
warning, partial, censored (below LoQ / above range), refused, simulated — expressed by icon,
label, colour and position together, never colour alone (directive §29). A refused scan
appears in history; hiding it would misrepresent the coverage record, which is exactly the
kind of quiet omission that produces false reassurance at review time.
