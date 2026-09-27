-- Measurement result invariants.
--
-- The README and docs/architecture/data-model.md both describe
-- `dose_only_when_valid` as a safety property of this system. Until this
-- migration existed, it was not: the invariant lived only in the Dart type
-- system, and a document claiming a database guarantee that the database does
-- not make is worse than no document.
--
-- Scope is deliberately narrow. This is not the full schema from
-- data-model.md; it is the slice needed to make the claimed invariant real.
-- The organisation, worker, badge and session tables arrive with Phase 7,
-- along with RLS.

-- ---------------------------------------------------------------------------
-- Domains
-- ---------------------------------------------------------------------------

-- Where a number came from. ADR-0006. Not a boolean, not a flag: a NOT NULL
-- column with a propagation trigger, because a flag can be forgotten,
-- defaulted, or lost when a record is copied.
create type data_domain as enum ('simulated', 'lab', 'field');

create type result_status as enum (
  -- May carry a dose.
  'valid',
  'valid_with_warning',
  -- Censored: the measurement succeeded, but the true value lies outside the
  -- interval the calibration can quantify.
  'below_quantification_limit',
  'above_range',
  'saturated',
  -- Refusals.
  'poor_image',
  'badge_expired',
  'badge_damaged',
  'badge_already_used',
  'unsupported_batch',
  'unsupported_calibration',
  'reference_patch_failure',
  'blank_failure',
  'sensor_blank_disagreement',
  'partial_shift',
  'environment_outside_validated_range',
  'contamination_suspected',
  'result_unreliable'
);

-- ---------------------------------------------------------------------------
-- Calibration models
-- ---------------------------------------------------------------------------

create table calibration_models (
  id uuid primary key default gen_random_uuid(),
  version text not null,
  formulation_version text not null,
  geometry_version text not null,

  -- Which pipeline code this model was fitted against. A model fitted on one
  -- feature definition must not be applied by a pipeline that computes those
  -- features differently; mismatch is UNSUPPORTED_CALIBRATION, not a
  -- best-effort reading. See measurement-engine/golden-vectors/README.md.
  algorithm_version text not null,
  feature_definition_version text not null,

  parameters jsonb not null,
  validated_range jsonb not null,
  environmental_domain jsonb not null,
  uncertainty_model jsonb not null,

  -- Which domains this model may be applied in. A simulated model cannot
  -- produce a field result.
  permitted_domains data_domain[] not null,

  checksum text not null,
  signature text,
  valid_from timestamptz not null default now(),
  valid_until timestamptz,
  created_at timestamptz not null default now(),

  constraint permitted_domains_not_empty
    check (array_length(permitted_domains, 1) >= 1),
  constraint calibration_models_version_unique unique (version)
);

comment on table calibration_models is
  'A versioned, checksummed calibration artefact. No coefficients live in '
  'application code.';

-- ---------------------------------------------------------------------------
-- Scans
-- ---------------------------------------------------------------------------

create table scans (
  id uuid primary key default gen_random_uuid(),
  captured_at timestamptz not null,
  image_hash text not null,
  device_model text,
  app_version text not null,
  algorithm_version text not null,
  data_domain data_domain not null,
  created_at timestamptz not null default now()
);

comment on column scans.data_domain is
  'Inherited by every result derived from this scan, enforced by trigger.';

-- ---------------------------------------------------------------------------
-- Measurement results
-- ---------------------------------------------------------------------------

create table measurement_results (
  id uuid primary key default gen_random_uuid(),
  scan_id uuid not null references scans (id),
  status result_status not null,

  dose_ppm_h numeric,
  uncertainty_ppm_h numeric,
  uncertainty_basis text,
  bound_ppm_h numeric,
  bound_direction text,

  calibration_model_id uuid references calibration_models (id),
  algorithm_version text not null,
  data_domain data_domain not null,

  supersedes_result_id uuid references measurement_results (id),
  superseded_at timestamptz,
  created_at timestamptz not null default now(),

  -- THE invariant. A failure is never a number.
  --
  -- This is an equivalence, not an implication: it forbids a dose on a
  -- non-valid status AND a valid status without a dose. Writing it as
  -- `status in (...) and dose is not null` would permit the second, which is
  -- how "valid, 0 ppm-h, no model" gets into a worker's health record.
  constraint dose_only_when_valid check (
    (status in ('valid', 'valid_with_warning')) = (dose_ppm_h is not null)
  ),

  -- A dose with no stated uncertainty is a false precision claim.
  constraint uncertainty_accompanies_dose check (
    dose_ppm_h is null or uncertainty_ppm_h is not null
  ),

  -- And an interval with no stated basis is a coverage claim by omission.
  -- Directive s36.
  constraint uncertainty_states_its_basis check (
    uncertainty_ppm_h is null
    or (uncertainty_basis is not null and length(trim(uncertainty_basis)) > 0)
  ),

  -- A one-sided bound belongs only to a censored result.
  constraint bound_only_when_censored check (
    status in ('below_quantification_limit', 'above_range', 'saturated')
    or (bound_ppm_h is null and bound_direction is null)
  ),

  constraint bound_direction_valid check (
    bound_direction is null or bound_direction in ('lower', 'upper')
  ),

  constraint bound_direction_accompanies_bound check (
    (bound_ppm_h is null) = (bound_direction is null)
  ),

  -- A dose without the model that produced it is not a measurement.
  constraint valid_requires_model check (
    status not in ('valid', 'valid_with_warning')
    or calibration_model_id is not null
  ),

  -- Exposure is a non-negative quantity.
  constraint dose_is_not_negative check (dose_ppm_h is null or dose_ppm_h >= 0),
  constraint uncertainty_is_not_negative check (
    uncertainty_ppm_h is null or uncertainty_ppm_h >= 0
  ),

  constraint no_self_supersession check (supersedes_result_id is distinct from id)
);

comment on constraint dose_only_when_valid on measurement_results is
  'The most important line in the schema: it makes "convert a failure into '
  '0.0 ppm-h" unrepresentable, which is otherwise one careless '
  'null-coalescing operator away.';

create index measurement_results_scan_id_idx on measurement_results (scan_id);
create index measurement_results_supersedes_idx
  on measurement_results (supersedes_result_id)
  where supersedes_result_id is not null;

-- ---------------------------------------------------------------------------
-- Domain propagation
-- ---------------------------------------------------------------------------

create or replace function enforce_result_data_domain()
returns trigger
language plpgsql
as $$
declare
  parent_domain data_domain;
  model_domains data_domain[];
begin
  select data_domain into parent_domain from scans where id = new.scan_id;

  if parent_domain is null then
    raise exception 'scan % does not exist', new.scan_id;
  end if;

  if new.data_domain <> parent_domain then
    raise exception
      'result domain % does not match scan domain %',
      new.data_domain, parent_domain
      using errcode = 'check_violation';
  end if;

  -- A model may only be applied in a domain it is permitted in. This is what
  -- stops a simulated calibration producing a field dose.
  if new.calibration_model_id is not null then
    select permitted_domains into model_domains
      from calibration_models where id = new.calibration_model_id;

    if not (new.data_domain = any (model_domains)) then
      raise exception
        'calibration model % is not permitted in domain %',
        new.calibration_model_id, new.data_domain
        using errcode = 'check_violation';
    end if;
  end if;

  return new;
end;
$$;

create trigger measurement_results_domain_check
  before insert or update on measurement_results
  for each row execute function enforce_result_data_domain();

-- ---------------------------------------------------------------------------
-- Immutability
-- ---------------------------------------------------------------------------

-- Directive s41: a measurement must be reproducible. If calibration improves,
-- a NEW result is inserted with supersedes_result_id set; the old row's
-- values are never touched. Only the supersession bookkeeping may change.
create or replace function reject_measurement_field_updates()
returns trigger
language plpgsql
as $$
begin
  if new.scan_id is distinct from old.scan_id
     or new.status is distinct from old.status
     or new.dose_ppm_h is distinct from old.dose_ppm_h
     or new.uncertainty_ppm_h is distinct from old.uncertainty_ppm_h
     or new.uncertainty_basis is distinct from old.uncertainty_basis
     or new.bound_ppm_h is distinct from old.bound_ppm_h
     or new.bound_direction is distinct from old.bound_direction
     or new.calibration_model_id is distinct from old.calibration_model_id
     or new.algorithm_version is distinct from old.algorithm_version
     or new.data_domain is distinct from old.data_domain
     or new.created_at is distinct from old.created_at then
    raise exception
      'measurement results are immutable; insert a superseding result instead'
      using errcode = 'restrict_violation';
  end if;
  return new;
end;
$$;

create trigger measurement_results_immutable
  before update on measurement_results
  for each row execute function reject_measurement_field_updates();

create or replace function reject_measurement_deletes()
returns trigger
language plpgsql
as $$
begin
  raise exception 'measurement results are append-only and are never deleted'
    using errcode = 'restrict_violation';
end;
$$;

create trigger measurement_results_no_delete
  before delete on measurement_results
  for each row execute function reject_measurement_deletes();
