-- pgTAP tests for the measurement result invariants.
--
--   supabase test db
--
-- These are the tests that make docs/architecture/data-model.md's claim about
-- `dose_only_when_valid` true rather than aspirational. The constraint is the
-- product's central promise expressed in SQL: a failed measurement must not be
-- representable as a number.

begin;
select plan(24);

-- ---------------------------------------------------------------------------
-- Structure
-- ---------------------------------------------------------------------------

select has_table('public', 'measurement_results', 'measurement_results exists');
select has_table('public', 'calibration_models', 'calibration_models exists');
select has_table('public', 'scans', 'scans exists');

select has_check('public', 'measurement_results',
  'measurement_results has check constraints');

select col_not_null('public', 'measurement_results', 'data_domain',
  'every result states which domain it belongs to');
select col_not_null('public', 'measurement_results', 'status',
  'every result states its status');

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

insert into calibration_models (
  id, version, formulation_version, geometry_version, algorithm_version,
  feature_definition_version, parameters, validated_range,
  environmental_domain, uncertainty_model, permitted_domains, checksum
) values (
  '11111111-1111-1111-1111-111111111111', 'sim-0.1', 'none', 'demo-badge-v0',
  'm0a', 'fdv-0.1.0-m0a', '{}'::jsonb, '{}'::jsonb, '{}'::jsonb, '{}'::jsonb,
  array['simulated']::data_domain[], 'deadbeef'
), (
  '22222222-2222-2222-2222-222222222222', 'field-0.1', 'none', 'demo-badge-v0',
  'm0a', 'fdv-0.1.0-m0a', '{}'::jsonb, '{}'::jsonb, '{}'::jsonb, '{}'::jsonb,
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

-- ---------------------------------------------------------------------------
-- THE invariant: a failure is never a number
-- ---------------------------------------------------------------------------

select throws_ok(
  $$insert into measurement_results
      (scan_id, status, dose_ppm_h, uncertainty_ppm_h, uncertainty_basis,
       algorithm_version, data_domain)
    values ('33333333-3333-3333-3333-333333333333', 'poor_image', 0.0, 0.1,
            'test', 'm0a', 'simulated')$$,
  '23514',
  null,
  'a refusal carrying 0.0 ppm-h is rejected'
);

select throws_ok(
  $$insert into measurement_results
      (scan_id, status, dose_ppm_h, uncertainty_ppm_h, uncertainty_basis,
       algorithm_version, data_domain)
    values ('33333333-3333-3333-3333-333333333333', 'above_range', 12.0, 1.0,
            'test', 'm0a', 'simulated')$$,
  '23514',
  null,
  'a censored result carrying a dose is rejected'
);

select throws_ok(
  $$insert into measurement_results
      (scan_id, status, calibration_model_id, algorithm_version, data_domain)
    values ('33333333-3333-3333-3333-333333333333', 'valid',
            '11111111-1111-1111-1111-111111111111', 'm0a', 'simulated')$$,
  '23514',
  null,
  'a valid result with no dose is rejected'
);

-- ---------------------------------------------------------------------------
-- A dose needs a model, an uncertainty, and a stated basis
-- ---------------------------------------------------------------------------

select throws_ok(
  $$insert into measurement_results
      (scan_id, status, dose_ppm_h, uncertainty_ppm_h, uncertainty_basis,
       algorithm_version, data_domain)
    values ('33333333-3333-3333-3333-333333333333', 'valid', 4.2, 0.5, 'test',
            'm0a', 'simulated')$$,
  '23514',
  null,
  'a dose with no calibration model is rejected'
);

select throws_ok(
  $$insert into measurement_results
      (scan_id, status, dose_ppm_h, calibration_model_id, algorithm_version,
       data_domain)
    values ('33333333-3333-3333-3333-333333333333', 'valid', 4.2,
            '11111111-1111-1111-1111-111111111111', 'm0a', 'simulated')$$,
  '23514',
  null,
  'a dose with no uncertainty is rejected'
);

select throws_ok(
  $$insert into measurement_results
      (scan_id, status, dose_ppm_h, uncertainty_ppm_h, calibration_model_id,
       algorithm_version, data_domain)
    values ('33333333-3333-3333-3333-333333333333', 'valid', 4.2, 0.5,
            '11111111-1111-1111-1111-111111111111', 'm0a', 'simulated')$$,
  '23514',
  null,
  'an uncertainty with no stated basis is rejected'
);

select throws_ok(
  $$insert into measurement_results
      (scan_id, status, dose_ppm_h, uncertainty_ppm_h, uncertainty_basis,
       calibration_model_id, algorithm_version, data_domain)
    values ('33333333-3333-3333-3333-333333333333', 'valid', 4.2, 0.5, '   ',
            '11111111-1111-1111-1111-111111111111', 'm0a', 'simulated')$$,
  '23514',
  null,
  'a blank uncertainty basis is rejected'
);

select throws_ok(
  $$insert into measurement_results
      (scan_id, status, dose_ppm_h, uncertainty_ppm_h, uncertainty_basis,
       calibration_model_id, algorithm_version, data_domain)
    values ('33333333-3333-3333-3333-333333333333', 'valid', -1.0, 0.5, 'test',
            '11111111-1111-1111-1111-111111111111', 'm0a', 'simulated')$$,
  '23514',
  null,
  'a negative dose is rejected'
);

-- ---------------------------------------------------------------------------
-- Censoring bounds
-- ---------------------------------------------------------------------------

select lives_ok(
  $$insert into measurement_results
      (scan_id, status, bound_ppm_h, bound_direction, algorithm_version,
       data_domain)
    values ('33333333-3333-3333-3333-333333333333', 'above_range', 40.0,
            'lower', 'm0a', 'simulated')$$,
  'an above-range result may keep a one-sided lower bound'
);

select throws_ok(
  $$insert into measurement_results
      (scan_id, status, bound_ppm_h, bound_direction, algorithm_version,
       data_domain)
    values ('33333333-3333-3333-3333-333333333333', 'poor_image', 40.0,
            'lower', 'm0a', 'simulated')$$,
  '23514',
  null,
  'a refusal may not carry a bound'
);

select throws_ok(
  $$insert into measurement_results
      (scan_id, status, bound_ppm_h, algorithm_version, data_domain)
    values ('33333333-3333-3333-3333-333333333333', 'saturated', 40.0, 'm0a',
            'simulated')$$,
  '23514',
  null,
  'a bound with no direction is rejected'
);

-- ---------------------------------------------------------------------------
-- The happy paths
-- ---------------------------------------------------------------------------

select lives_ok(
  $$insert into measurement_results
      (id, scan_id, status, dose_ppm_h, uncertainty_ppm_h, uncertainty_basis,
       calibration_model_id, algorithm_version, data_domain)
    values ('55555555-5555-5555-5555-555555555555',
            '33333333-3333-3333-3333-333333333333', 'valid', 4.2, 0.5,
            'provisional: simulated model residual spread',
            '11111111-1111-1111-1111-111111111111', 'm0a', 'simulated')$$,
  'a complete valid simulated result is accepted'
);

select lives_ok(
  $$insert into measurement_results
      (scan_id, status, algorithm_version, data_domain)
    values ('33333333-3333-3333-3333-333333333333', 'unsupported_calibration',
            'm0a', 'simulated')$$,
  'a refusal with no numbers at all is accepted'
);

-- ---------------------------------------------------------------------------
-- Domain propagation and calibration gating
-- ---------------------------------------------------------------------------

select throws_ok(
  $$insert into measurement_results
      (scan_id, status, algorithm_version, data_domain)
    values ('33333333-3333-3333-3333-333333333333', 'poor_image', 'm0a',
            'field')$$,
  null,
  null,
  'a result cannot claim a different domain from its scan'
);

select throws_ok(
  $$insert into measurement_results
      (scan_id, status, dose_ppm_h, uncertainty_ppm_h, uncertainty_basis,
       calibration_model_id, algorithm_version, data_domain)
    values ('44444444-4444-4444-4444-444444444444', 'valid', 4.2, 0.5, 'test',
            '11111111-1111-1111-1111-111111111111', 'm0a', 'field')$$,
  null,
  null,
  'a simulated-only calibration model cannot produce a field dose'
);

select lives_ok(
  $$insert into measurement_results
      (scan_id, status, dose_ppm_h, uncertainty_ppm_h, uncertainty_basis,
       calibration_model_id, algorithm_version, data_domain)
    values ('44444444-4444-4444-4444-444444444444', 'valid', 4.2, 0.5,
            'from validated model', '22222222-2222-2222-2222-222222222222',
            'm0a', 'field')$$,
  'a field-permitted model may produce a field dose'
);

-- ---------------------------------------------------------------------------
-- Immutability and supersession
-- ---------------------------------------------------------------------------

select throws_ok(
  $$update measurement_results set dose_ppm_h = 99.0
      where id = '55555555-5555-5555-5555-555555555555'$$,
  '23001',
  null,
  'a recorded dose cannot be edited'
);

select throws_ok(
  $$update measurement_results set status = 'poor_image'
      where id = '55555555-5555-5555-5555-555555555555'$$,
  '23001',
  null,
  'a recorded status cannot be edited'
);

select throws_ok(
  $$delete from measurement_results
      where id = '55555555-5555-5555-5555-555555555555'$$,
  '23001',
  null,
  'results are append-only and are never deleted'
);

select lives_ok(
  $$update measurement_results set superseded_at = now()
      where id = '55555555-5555-5555-5555-555555555555'$$,
  'supersession bookkeeping may still be written'
);

select lives_ok(
  $$insert into measurement_results
      (scan_id, status, dose_ppm_h, uncertainty_ppm_h, uncertainty_basis,
       calibration_model_id, algorithm_version, data_domain,
       supersedes_result_id)
    values ('33333333-3333-3333-3333-333333333333', 'valid', 4.4, 0.4,
            'recalculated', '11111111-1111-1111-1111-111111111111', 'm0a',
            'simulated', '55555555-5555-5555-5555-555555555555')$$,
  'a recalculation is recorded as a new superseding result'
);

select is(
  (select dose_ppm_h from measurement_results
     where id = '55555555-5555-5555-5555-555555555555'),
  4.2::numeric,
  'the superseded result keeps its original value'
);

select * from finish();
rollback;
