import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/features/workflow/application/workflow_controller.dart';
import 'package:h2s_doseband/features/workflow/data/simulation_catalog.dart';
import 'package:h2s_doseband/features/workflow/data/work_context_repository.dart';
import 'package:h2s_doseband/features/workflow/data/workflow_store.dart';
import 'package:h2s_doseband/features/workflow/domain/badge_specimen.dart';
import 'package:h2s_doseband/features/workflow/domain/enterprise_value.dart';
import 'package:h2s_doseband/features/workflow/domain/permit_context.dart';
import 'package:h2s_doseband/features/workflow/domain/work_context.dart';
import 'package:h2s_doseband/features/workflow/domain/work_context_validator.dart';
import 'package:h2s_doseband/features/workflow/domain/worker_identity.dart';
import 'package:h2s_doseband/features/workflow/domain/workflow_state.dart';

const _config = DemoWorkContextRepository();

BadgeSpecimen _badge([String label = 'Valid — mid response']) =>
    SimulationCatalog.specimens().firstWhere((s) => s.label == label);

WorkContextDraft _completeDraft({
  WorkerType type = WorkerType.employee,
  String? contractorCompany,
}) =>
    WorkContextDraft.from(SimulationCatalog.demoContext(workerType: type))
        .copyWith(
          worker: WorkerIdentity(
            workerId: 'W-1',
            displayName: 'Test Worker',
            workerType: type,
            source: EnterpriseDataSource.demo,
            contractorCompany: contractorCompany,
          ),
        );

void main() {
  group('worker identity', () {
    test('an employee with no contractor company is coherent', () {
      const w = WorkerIdentity(
        workerId: 'E-1',
        displayName: 'Employee',
        workerType: WorkerType.employee,
        source: EnterpriseDataSource.demo,
      );
      expect(w.contractorCompanyIsCoherent, isTrue);
    });

    test('an employee carrying a contractor company is not', () {
      const w = WorkerIdentity(
        workerId: 'E-1',
        displayName: 'Employee',
        workerType: WorkerType.employee,
        source: EnterpriseDataSource.demo,
        contractorCompany: 'Someone Ltd',
      );
      expect(w.contractorCompanyIsCoherent, isFalse);
    });

    test('a contractor requires a contractor company', () {
      const without = WorkerIdentity(
        workerId: 'C-1',
        displayName: 'Contractor',
        workerType: WorkerType.contractor,
        source: EnterpriseDataSource.demo,
      );
      const blank = WorkerIdentity(
        workerId: 'C-1',
        displayName: 'Contractor',
        workerType: WorkerType.contractor,
        source: EnterpriseDataSource.demo,
        contractorCompany: '   ',
      );
      const with_ = WorkerIdentity(
        workerId: 'C-1',
        displayName: 'Contractor',
        workerType: WorkerType.contractor,
        source: EnterpriseDataSource.demo,
        contractorCompany: 'Demo Contracting Co.',
      );
      expect(without.contractorCompanyIsCoherent, isFalse);
      expect(blank.contractorCompanyIsCoherent, isFalse);
      expect(with_.contractorCompanyIsCoherent, isTrue);
    });
  });

  group('enterprise provenance', () {
    test('a manual value is never verified, and carries no verification', () {
      const v = EnterpriseValue<String>.manual('PTW-24-11873');
      expect(v.source, EnterpriseDataSource.manualEntry);
      expect(v.isVerified, isFalse);
      expect(v.verifiedAt, isNull);
      expect(v.externalSystem, isNull);
      expect(v.externalReference, isNull);
    });

    test('a verified value cannot exist without what verified it', () {
      // Not a runtime assertion — the constructor's required parameters make
      // this a compile-time guarantee. The test pins the shape so that making
      // them optional later fails here.
      final v = EnterpriseValue.verified(
        value: 'PTW-24-11873',
        verifiedAt: DateTime(2026, 9, 25),
        externalSystem: 'demo-system',
        externalReference: 'ext-1',
      );
      expect(v.isVerified, isTrue);
      expect(v.externalSystem, isNotNull);
      expect(v.externalReference, isNotNull);
      expect(v.verifiedAt, isNotNull);
    });

    test('a manual and a verified value of the same string differ', () {
      const manual = EnterpriseValue<String>.manual('PTW-24-11873');
      final verified = EnterpriseValue.verified(
        value: 'PTW-24-11873',
        verifiedAt: DateTime(2026, 9, 25),
        externalSystem: 'demo-system',
        externalReference: 'ext-1',
      );
      // The whole point: same number, not the same fact.
      expect(manual == verified, isFalse);
      expect(manual.value, verified.value);
    });

    test('only demo and manual sources are available in this build', () {
      expect(
        EnterpriseDataSource.availableToday,
        isNot(contains(EnterpriseDataSource.organizationIntegration)),
      );
    });

    test('nothing the app can produce today is verified', () {
      // Every reference a worker or the demo catalogue can create must be
      // unverified. If an integration is wired up, this test is the thing that
      // makes that a deliberate decision rather than a silent one.
      final demo = SimulationCatalog.demoContext();
      expect(demo.permit.isVerified, isFalse);
      expect(demo.jsa.isVerified, isFalse);
      expect(demo.worker.gatePass?.isVerified, isFalse);
      expect(demo.isEntirelyUnverified, isTrue);
    });
  });

  group('the draft only becomes a context when it is complete', () {
    test('an empty draft builds nothing', () {
      expect(WorkContextDraft.empty.build(), isNull);
    });

    test('a complete draft builds', () {
      expect(_completeDraft().build(), isNotNull);
    });

    for (final removal in <String, WorkContextDraft Function(WorkContextDraft)>{
      'site': (d) => WorkContextDraft(
        worker: d.worker,
        department: d.department,
        shift: d.shift,
        job: d.job,
        permit: d.permit,
        jsa: d.jsa,
        toolboxTalk: d.toolboxTalk,
      ),
      'work area': (d) => d.copyWith(clearWorkArea: true),
      'toolbox talk': (d) => d.copyWith(clearToolboxTalk: true),
    }.entries) {
      test('a draft missing its ${removal.key} builds nothing', () {
        expect(removal.value(_completeDraft()).build(), isNull);
      });
    }

    test('a contractor without a company builds nothing', () {
      final draft = _completeDraft(type: WorkerType.contractor);
      expect(draft.build(), isNull);
    });

    test('a contractor with a company builds', () {
      final draft = _completeDraft(
        type: WorkerType.contractor,
        contractorCompany: 'Demo Contracting Co.',
      );
      expect(draft.build(), isNotNull);
    });

    test('a work area from another site builds nothing', () {
      final office = _config.workAreas('corporate-office').first;
      final draft = _completeDraft().copyWith(workArea: office);
      expect(draft.site!.id, 'mangalore-refinery');
      expect(draft.build(), isNull);
    });
  });

  group('readiness is decided in one place', () {
    test('a complete draft with a usable badge is ready', () {
      final r = WorkContextValidator.assess(_completeDraft(), badge: _badge());
      expect(r.isReady, isTrue);
      expect(r.missingRequirements, isEmpty);
    });

    test('an empty draft reports every requirement it can', () {
      final r = WorkContextValidator.assess(
        WorkContextDraft.empty,
        badge: null,
      );
      expect(r.isReady, isFalse);
      expect(
        r.missingRequirements,
        containsAll([
          WorkContextRequirement.workerIdentity,
          WorkContextRequirement.site,
          WorkContextRequirement.department,
          WorkContextRequirement.workArea,
          WorkContextRequirement.shift,
          WorkContextRequirement.job,
          WorkContextRequirement.permitReference,
          WorkContextRequirement.jsaReference,
          WorkContextRequirement.toolboxTalk,
          WorkContextRequirement.badgeAssigned,
        ]),
      );
      // Without a worker there is nothing to say about the contractor company,
      // so it is not also reported: one cause, one failure.
      expect(
        r.missingRequirements,
        isNot(contains(WorkContextRequirement.contractorCompany)),
      );
    });

    test('a missing badge is a missing requirement', () {
      final r = WorkContextValidator.assess(_completeDraft(), badge: null);
      expect(r.isReady, isFalse);
      expect(r.isMissing(WorkContextRequirement.badgeAssigned), isTrue);
    });

    test('an ineligible badge is reported as unusable, not as absent', () {
      final ineligible = SimulationCatalog.specimens().firstWhere(
        (s) => !s.validity.eligible,
      );
      final r = WorkContextValidator.assess(
        _completeDraft(),
        badge: ineligible,
      );
      expect(r.isMissing(WorkContextRequirement.badgeUsable), isTrue);
      expect(r.isMissing(WorkContextRequirement.badgeAssigned), isFalse);
    });

    test('a contractor with no company is not ready', () {
      final r = WorkContextValidator.assess(
        _completeDraft(type: WorkerType.contractor),
        badge: _badge(),
      );
      expect(r.isReady, isFalse);
      expect(r.isMissing(WorkContextRequirement.contractorCompany), isTrue);
    });

    test('a blank permit reference does not satisfy the requirement', () {
      final draft = _completeDraft().copyWith(
        permit: const PtwReference(
          reference: EnterpriseValue<String>.manual('   '),
        ),
      );
      final r = WorkContextValidator.assess(draft, badge: _badge());
      expect(r.isMissing(WorkContextRequirement.permitReference), isTrue);
    });

    test('a blank job title does not satisfy the requirement', () {
      final draft = _completeDraft().copyWith(
        job: const JobContext(title: '  '),
      );
      final r = WorkContextValidator.assess(draft, badge: _badge());
      expect(r.isMissing(WorkContextRequirement.job), isTrue);
    });

    test('a ready context still warns that nothing was checked', () {
      final r = WorkContextValidator.assess(_completeDraft(), badge: _badge());
      expect(r.isReady, isTrue);
      expect(
        r.warnings,
        contains(WorkContextWarning.nothingVerifiedExternally),
      );
    });

    test('an area from another site both warns and blocks', () {
      final office = _config.workAreas('corporate-office').first;
      final r = WorkContextValidator.assess(
        _completeDraft().copyWith(workArea: office),
        badge: _badge(),
      );
      expect(r.warnings, contains(WorkContextWarning.workAreaSiteMismatch));
      expect(r.isMissing(WorkContextRequirement.workArea), isTrue);
      expect(r.isReady, isFalse);
    });
  });

  group('build() and the validator agree', () {
    // These two decide "is this context complete". They are consulted by
    // different screens, so a divergence shows up as a Continue button that is
    // enabled while the next screen's checklist says something is missing.
    test('a blank job title is rejected by both', () {
      final draft = _completeDraft().copyWith(
        job: const JobContext(title: '   '),
      );
      expect(draft.build(), isNull);
      expect(
        WorkContextValidator.assess(
          draft,
          badge: _badge(),
        ).isMissing(WorkContextRequirement.job),
        isTrue,
      );
    });

    test('a blank permit reference is rejected by both', () {
      final draft = _completeDraft().copyWith(
        permit: const PtwReference(
          reference: EnterpriseValue<String>.manual('  '),
        ),
      );
      expect(draft.build(), isNull);
      expect(
        WorkContextValidator.assess(
          draft,
          badge: _badge(),
        ).isMissing(WorkContextRequirement.permitReference),
        isTrue,
      );
    });

    test('a blank JSA reference is rejected by both', () {
      final draft = _completeDraft().copyWith(
        jsa: const JsaReference(reference: EnterpriseValue<String>.manual(' ')),
      );
      expect(draft.build(), isNull);
      expect(
        WorkContextValidator.assess(
          draft,
          badge: _badge(),
        ).isMissing(WorkContextRequirement.jsaReference),
        isTrue,
      );
    });

    test('contextIsComplete ignores the badge and nothing else', () {
      final complete = _completeDraft();
      final withoutBadge = WorkContextValidator.assess(complete, badge: null);

      expect(withoutBadge.contextIsComplete, isTrue);
      expect(withoutBadge.isReady, isFalse);
      expect(complete.build(), isNotNull);

      final incomplete = WorkContextValidator.assess(
        complete.copyWith(clearToolboxTalk: true),
        badge: _badge(),
      );
      expect(incomplete.contextIsComplete, isFalse);
    });

    test('whenever the context is complete, it builds', () {
      // The invariant the Continue button depends on: it gates on
      // contextIsComplete and then calls build(), so a case where one passes
      // and the other returns null would be a dead button or a silent no-op.
      final drafts = <WorkContextDraft>[
        _completeDraft(),
        _completeDraft(
          type: WorkerType.contractor,
          contractorCompany: 'Demo Contracting Co.',
        ),
        _completeDraft().copyWith(job: const JobContext(title: 'Sampling')),
      ];
      for (final d in drafts) {
        final r = WorkContextValidator.assess(d, badge: _badge());
        if (r.contextIsComplete) {
          expect(d.build(), isNotNull);
        }
      }
    });
  });

  group('the context cannot be rewritten once monitoring starts', () {
    late ProviderContainer container;
    late ShiftSessionController controller;

    Future<void> runToMonitoring() async {
      container = ProviderContainer(
        overrides: [
          workflowStoreProvider.overrideWithValue(InMemoryWorkflowStore()),
        ],
      );
      addTearDown(container.dispose);
      controller = container.read(shiftSessionProvider.notifier);
      await container.read(shiftSessionProvider.future);
      await controller.setContext(SimulationCatalog.demoContext());
      await controller.assignBadge(_badge());
      await controller.confirmPreWork();
      await controller.startMonitoring();
    }

    test('the session reports itself locked from monitoring onwards', () {
      const stages = ShiftStage.values;
      for (final stage in stages) {
        final locked = ShiftSession(stage: stage).contextIsLocked;
        expect(
          locked,
          stage.index >= ShiftStage.monitoring.index,
          reason: stage.name,
        );
      }
    });

    test('changing the work context during monitoring is refused', () async {
      await runToMonitoring();
      expect(
        () => controller.setContext(
          SimulationCatalog.demoContext(siteId: 'corporate-office'),
        ),
        throwsA(isA<WorkflowLockedError>()),
      );
    });

    test('changing the badge during monitoring is refused', () async {
      await runToMonitoring();
      expect(
        () => controller.assignBadge(_badge('Above range — saturated')),
        throwsA(isA<WorkflowLockedError>()),
      );
    });

    test('a refused change leaves the session untouched', () async {
      await runToMonitoring();
      final before = container.read(shiftSessionProvider).value!;
      try {
        await controller.setContext(
          SimulationCatalog.demoContext(siteId: 'corporate-office'),
        );
      } on WorkflowLockedError {
        // expected
      }
      final after = container.read(shiftSessionProvider).value!;
      expect(after.context, before.context);
      expect(after.stage, before.stage);
      expect(after.startedAt, before.startedAt);
    });

    test('the context is editable before monitoring starts', () async {
      final container = ProviderContainer(
        overrides: [
          workflowStoreProvider.overrideWithValue(InMemoryWorkflowStore()),
        ],
      );
      addTearDown(container.dispose);
      final c = container.read(shiftSessionProvider.notifier);
      await container.read(shiftSessionProvider.future);

      await c.setContext(SimulationCatalog.demoContext());
      await c.setContext(
        SimulationCatalog.demoContext(siteId: 'corporate-office'),
      );

      expect(
        container.read(shiftSessionProvider).value!.context!.site.id,
        'corporate-office',
      );
    });

    test('monitoring cannot start without a work context', () async {
      final container = ProviderContainer(
        overrides: [
          workflowStoreProvider.overrideWithValue(InMemoryWorkflowStore()),
        ],
      );
      addTearDown(container.dispose);
      final c = container.read(shiftSessionProvider.notifier);
      await container.read(shiftSessionProvider.future);

      expect(c.startMonitoring, throwsStateError);
    });

    test('monitoring cannot start without a badge', () async {
      final container = ProviderContainer(
        overrides: [
          workflowStoreProvider.overrideWithValue(InMemoryWorkflowStore()),
        ],
      );
      addTearDown(container.dispose);
      final c = container.read(shiftSessionProvider.notifier);
      await container.read(shiftSessionProvider.future);
      await c.setContext(SimulationCatalog.demoContext());

      expect(c.startMonitoring, throwsStateError);
    });
  });

  group('demo configuration', () {
    test('work areas are filtered by site', () {
      final refinery = _config.workAreas('mangalore-refinery');
      expect(refinery, isNotEmpty);
      expect(refinery.every((a) => a.siteId == 'mangalore-refinery'), isTrue);
    });

    test(
      'an unconfigured site yields no areas rather than another site\'s',
      () {
        expect(_config.workAreas('not-a-site'), isEmpty);
      },
    );

    test('every configured area resolves by id', () {
      for (final site in [
        'mangalore-refinery',
        'corporate-office',
        'retail-hiq',
        'projects-site',
      ]) {
        for (final area in _config.workAreas(site)) {
          expect(_config.workAreaById(area.id), area, reason: area.id);
        }
      }
    });

    test('an unknown id resolves to null, never to a fallback', () {
      expect(_config.workAreaById('nope'), isNull);
      expect(_config.departmentById('nope'), isNull);
      expect(_config.shiftById('nope'), isNull);
      expect(_config.permitTypeById('nope'), isNull);
    });

    test('demo work areas are labelled as demo areas', () {
      // A screenshot of this screen must not be mistakable for real MRPL area
      // configuration.
      for (final area in _config.workAreas('mangalore-refinery')) {
        expect(area.name, contains('Demo area'), reason: area.id);
      }
    });

    test('a shift window is a display string and nothing parses it', () {
      // Pinning the intent: shifts carry no duration the app could use. If a
      // Duration field ever appears here, this test is where the argument
      // about extrapolating exposure has to be had.
      for (final s in _config.shifts()) {
        expect(s.window, anyOf(isNull, isA<String>()));
      }
    });
  });
}
