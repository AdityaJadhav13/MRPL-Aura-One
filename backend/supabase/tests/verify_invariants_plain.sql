-- Plain-SQL verification of the measurement result invariants.
--
-- A companion to measurement_result_invariants_test.sql, which needs pgTAP and
-- therefore Docker. This file needs neither: any PostgreSQL 13+ can run it.
--
--   createdb doseband
--   psql -d doseband -f backend/supabase/migrations/20260923000000_measurement_result_invariants.sql
--   psql -d doseband -f backend/supabase/tests/verify_invariants_plain.sql
--
-- It exists because the invariant it checks is the product's central promise,
-- and a promise that can only be checked when Docker happens to be running is
-- one that will go unchecked.

\set ON_ERROR_STOP on

create temporary table _results (
  ordinal serial,
  label text,
  expectation text,
  outcome text,
  detail text
);

create or replace function _expect_rejected(stmt text, label text)
returns void language plpgsql as $$
begin
  execute stmt;
  insert into _results (label, expectation, outcome, detail)
    values (label, 'rejected', 'FAIL', 'statement was accepted');
exception when others then
  insert into _results (label, expectation, outcome, detail)
    values (label, 'rejected', 'pass', sqlstate);
end;
$$;

create or replace function _expect_accepted(stmt text, label text)
returns void language plpgsql as $$
begin
  execute stmt;
  insert into _results (label, expectation, outcome, detail)
    values (label, 'accepted', 'pass', '');
exception when others then
  insert into _results (label, expectation, outcome, detail)
    values (label, 'accepted', 'FAIL', sqlstate || ': ' || sqlerrm);
end;
$$;

-- --------------------------------------------------------------------------
-- Fixtures
-- --------------------------------------------------------------------------

insert into calibration_models (
  id, version, formulation_version, geometry_version, algorithm_version,
  feature_definition_version, parameters, validated_range,
  environmental_domain, uncertainty_model, permitted_domains, checksum
) values (
  '11111111-1111-1111-1111-111111111111', 'sim-0.1', 'none', 'demo-badge-v0',
  'm0a', 'fdv-0.1.0-m0a', '{}', '{}', '{}', '{}',
  array['simulated']::data_domain[], 'deadbeef'
), (
  '22222222-2222-2222-2222-222222222222', 'field-0.1', 'none', 'demo-badge-v0',
  'm0a', 'fdv-0.1.0-m0a', '{}', '{}', '{}', '{}',
  array['lab','field']::data_domain[], 'cafebabe'
);

insert into scans (
  id, captured_at, image_hash, app_version, algorithm_version, data_domain
) values (
  '33333333-3333-3333-3333-333333333333', now(), 'hash-sim', '0.1.0', 'm0a',
  'simulated'
), (
  '44444444-4444-4444-4444-444444444444', now(), 'hash-field', '0.1.0', 'm0a',
  'field'
);

-- --------------------------------------------------------------------------
-- The invariant: a failure is never a number
-- --------------------------------------------------------------------------

select _expect_rejected($$
  insert into measurement_results (scan_id, status, dose_ppm_h,
    uncertainty_ppm_h, uncertainty_basis, algorithm_version, data_domain)
  values ('33333333-3333-3333-3333-333333333333', 'poor_image', 0.0, 0.1,
          'test', 'm0a', 'simulated')$$,
  'refusal carrying 0.0 ppm-h');

select _expect_rejected($$
  insert into measurement_results (scan_id, status, dose_ppm_h,
    uncertainty_ppm_h, uncertainty_basis, algorithm_version, data_domain)
  values ('33333333-3333-3333-3333-333333333333', 'above_range', 12.0, 1.0,
          'test', 'm0a', 'simulated')$$,
  'censored result carrying a dose');

select _expect_rejected($$
  insert into measurement_results (scan_id, status, calibration_model_id,
    algorithm_version, data_domain)
  values ('33333333-3333-3333-3333-333333333333', 'valid',
          '11111111-1111-1111-1111-111111111111', 'm0a', 'simulated')$$,
  'valid result with no dose');

-- --------------------------------------------------------------------------
-- A dose needs a model, an uncertainty, and a stated basis
-- --------------------------------------------------------------------------

select _expect_rejected($$
  insert into measurement_results (scan_id, status, dose_ppm_h,
    uncertainty_ppm_h, uncertainty_basis, algorithm_version, data_domain)
  values ('33333333-3333-3333-3333-333333333333', 'valid', 4.2, 0.5, 'test',
          'm0a', 'simulated')$$,
  'dose with no calibration model');

select _expect_rejected($$
  insert into measurement_results (scan_id, status, dose_ppm_h,
    calibration_model_id, algorithm_version, data_domain)
  values ('33333333-3333-3333-3333-333333333333', 'valid', 4.2,
          '11111111-1111-1111-1111-111111111111', 'm0a', 'simulated')$$,
  'dose with no uncertainty');

select _expect_rejected($$
  insert into measurement_results (scan_id, status, dose_ppm_h,
    uncertainty_ppm_h, calibration_model_id, algorithm_version, data_domain)
  values ('33333333-3333-3333-3333-333333333333', 'valid', 4.2, 0.5,
          '11111111-1111-1111-1111-111111111111', 'm0a', 'simulated')$$,
  'uncertainty with no stated basis');

select _expect_rejected($$
  insert into measurement_results (scan_id, status, dose_ppm_h,
    uncertainty_ppm_h, uncertainty_basis, calibration_model_id,
    algorithm_version, data_domain)
  values ('33333333-3333-3333-3333-333333333333', 'valid', 4.2, 0.5, '   ',
          '11111111-1111-1111-1111-111111111111', 'm0a', 'simulated')$$,
  'blank uncertainty basis');

select _expect_rejected($$
  insert into measurement_results (scan_id, status, dose_ppm_h,
    uncertainty_ppm_h, uncertainty_basis, calibration_model_id,
    algorithm_version, data_domain)
  values ('33333333-3333-3333-3333-333333333333', 'valid', -1.0, 0.5, 'test',
          '11111111-1111-1111-1111-111111111111', 'm0a', 'simulated')$$,
  'negative dose');

-- --------------------------------------------------------------------------
-- Censoring bounds
-- --------------------------------------------------------------------------

select _expect_accepted($$
  insert into measurement_results (scan_id, status, bound_ppm_h,
    bound_direction, algorithm_version, data_domain)
  values ('33333333-3333-3333-3333-333333333333', 'above_range', 40.0, 'lower',
          'm0a', 'simulated')$$,
  'above-range result keeps a one-sided bound');

select _expect_rejected($$
  insert into measurement_results (scan_id, status, bound_ppm_h,
    bound_direction, algorithm_version, data_domain)
  values ('33333333-3333-3333-3333-333333333333', 'poor_image', 40.0, 'lower',
          'm0a', 'simulated')$$,
  'refusal carrying a bound');

select _expect_rejected($$
  insert into measurement_results (scan_id, status, bound_ppm_h,
    algorithm_version, data_domain)
  values ('33333333-3333-3333-3333-333333333333', 'saturated', 40.0, 'm0a',
          'simulated')$$,
  'bound with no direction');

-- --------------------------------------------------------------------------
-- Happy paths
-- --------------------------------------------------------------------------

select _expect_accepted($$
  insert into measurement_results (id, scan_id, status, dose_ppm_h,
    uncertainty_ppm_h, uncertainty_basis, calibration_model_id,
    algorithm_version, data_domain)
  values ('55555555-5555-5555-5555-555555555555',
          '33333333-3333-3333-3333-333333333333', 'valid', 4.2, 0.5,
          'provisional: simulated model residual spread',
          '11111111-1111-1111-1111-111111111111', 'm0a', 'simulated')$$,
  'complete valid simulated result');

select _expect_accepted($$
  insert into measurement_results (scan_id, status, algorithm_version,
    data_domain)
  values ('33333333-3333-3333-3333-333333333333', 'unsupported_calibration',
          'm0a', 'simulated')$$,
  'refusal with no numbers at all');

-- --------------------------------------------------------------------------
-- Domain propagation and calibration gating
-- --------------------------------------------------------------------------

select _expect_rejected($$
  insert into measurement_results (scan_id, status, algorithm_version,
    data_domain)
  values ('33333333-3333-3333-3333-333333333333', 'poor_image', 'm0a',
          'field')$$,
  'result claiming a different domain from its scan');

select _expect_rejected($$
  insert into measurement_results (scan_id, status, dose_ppm_h,
    uncertainty_ppm_h, uncertainty_basis, calibration_model_id,
    algorithm_version, data_domain)
  values ('44444444-4444-4444-4444-444444444444', 'valid', 4.2, 0.5, 'test',
          '11111111-1111-1111-1111-111111111111', 'm0a', 'field')$$,
  'simulated-only model producing a field dose');

select _expect_accepted($$
  insert into measurement_results (scan_id, status, dose_ppm_h,
    uncertainty_ppm_h, uncertainty_basis, calibration_model_id,
    algorithm_version, data_domain)
  values ('44444444-4444-4444-4444-444444444444', 'valid', 4.2, 0.5,
          'from validated model', '22222222-2222-2222-2222-222222222222',
          'm0a', 'field')$$,
  'field-permitted model producing a field dose');

-- --------------------------------------------------------------------------
-- Immutability and supersession
-- --------------------------------------------------------------------------

select _expect_rejected($$
  update measurement_results set dose_ppm_h = 99.0
    where id = '55555555-5555-5555-5555-555555555555'$$,
  'editing a recorded dose');

select _expect_rejected($$
  update measurement_results set status = 'poor_image'
    where id = '55555555-5555-5555-5555-555555555555'$$,
  'editing a recorded status');

select _expect_rejected($$
  delete from measurement_results
    where id = '55555555-5555-5555-5555-555555555555'$$,
  'deleting a result');

select _expect_accepted($$
  update measurement_results set superseded_at = now()
    where id = '55555555-5555-5555-5555-555555555555'$$,
  'writing supersession bookkeeping');

select _expect_accepted($$
  insert into measurement_results (scan_id, status, dose_ppm_h,
    uncertainty_ppm_h, uncertainty_basis, calibration_model_id,
    algorithm_version, data_domain, supersedes_result_id)
  values ('33333333-3333-3333-3333-333333333333', 'valid', 4.4, 0.4,
          'recalculated', '11111111-1111-1111-1111-111111111111', 'm0a',
          'simulated', '55555555-5555-5555-5555-555555555555')$$,
  'recording a superseding result');

do $$
declare original numeric;
begin
  select dose_ppm_h into original from measurement_results
    where id = '55555555-5555-5555-5555-555555555555';
  insert into _results (label, expectation, outcome, detail)
    values ('superseded result keeps its original value', 'accepted',
            case when original = 4.2 then 'pass' else 'FAIL' end,
            'dose is ' || coalesce(original::text, 'null'));
end;
$$;

-- --------------------------------------------------------------------------
-- Report
-- --------------------------------------------------------------------------

select ordinal, outcome, expectation, label, detail
  from _results order by ordinal;

select
  count(*) filter (where outcome = 'pass') as passed,
  count(*) filter (where outcome = 'FAIL') as failed,
  count(*) as total
from _results;

do $$
declare failures integer;
begin
  select count(*) into failures from _results where outcome = 'FAIL';
  if failures > 0 then
    raise exception '% invariant check(s) FAILED', failures;
  end if;
  raise notice 'all invariant checks passed';
end;
$$;
