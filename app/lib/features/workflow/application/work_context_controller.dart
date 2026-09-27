import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../operations/application/operations_repository.dart';
import '../data/work_context_repository.dart';
import '../domain/enterprise_value.dart';
import '../domain/permit_context.dart';
import '../domain/work_context.dart';
import '../domain/work_context_validator.dart';
import '../domain/work_taxonomy.dart';
import '../domain/worker_identity.dart';
import '../domain/workflow_state.dart';
import 'workflow_controller.dart';

/// Where the selectable departments, areas, shifts and permit categories come
/// from. Overridden in tests; replaced wholesale when real configuration or an
/// MRPL integration exists.
final workContextRepositoryProvider = Provider<WorkContextRepository>(
  (_) => const DemoWorkContextRepository(),
);

/// The work context the worker is filling in.
///
/// Separate from [shiftSessionProvider] on purpose. The session holds committed
/// state that is written to storage on every transition; this holds a form in
/// progress, which is neither committed nor persisted. A worker who abandons
/// half a form has not started a monitored period, and storing the fragment
/// would only create a half-context that the decoder would later have to
/// refuse.
final workContextDraftProvider =
    NotifierProvider<WorkContextDraftController, WorkContextDraft>(
      WorkContextDraftController.new,
    );

class WorkContextDraftController extends Notifier<WorkContextDraft> {
  @override
  WorkContextDraft build() {
    // Re-opening an already-committed context (the worker went back a step,
    // or is starting the next period) shows what was committed.
    final session = ref.watch(shiftSessionProvider).value;
    final committed = session?.context;
    if (committed != null) return WorkContextDraft.from(committed);
    return _fromDirectory() ?? WorkContextDraft.empty;
  }

  /// Starts the form from the signed-in person's directory record: who they
  /// are, and their usual site, department, area and shift. The worker still
  /// confirms the shift and area and records the job, permit and JSA.
  WorkContextDraft? _fromDirectory() {
    final actor = ref.watch(currentActorProvider);
    final directory = ref.watch(operationsProvider).value;
    final person = actor == null ? null : directory?.person(actor.personId);
    if (person == null) return null;
    const repo = DemoWorkContextRepository();
    final site = ref
        .watch(availableSitesProvider)
        .where((s) => s.id == person.siteId)
        .firstOrNull;
    return WorkContextDraft(
      worker: WorkerIdentity(
        workerId: person.personId,
        displayName: person.displayName,
        workerType: person.workerType,
        // No identity provider is connected, so every identity is
        // presentation data whatever the sign-in screen checked.
        source: EnterpriseDataSource.demo,
        contractorCompany: person.contractorCompany,
      ),
      site: site == null ? null : SiteRef(id: site.id, name: site.name),
      department: repo.departmentById(person.departmentId),
      workArea: repo.workAreaById(person.defaultWorkAreaId ?? ''),
      shift: repo.shiftById(person.defaultShiftId ?? ''),
    );
  }

  void setSite(SiteRef site) {
    final keepArea = state.workArea?.siteId == site.id;
    state = state.copyWith(site: site, clearWorkArea: !keepArea);
  }

  void setDepartment(Department d) => state = state.copyWith(department: d);

  void setWorkArea(WorkArea a) => state = state.copyWith(workArea: a);

  void setShift(WorkShift s) => state = state.copyWith(shift: s);

  void setJob(JobContext job) => state = state.copyWith(job: job);

  void setGatePass(String value) {
    final worker = state.worker;
    if (worker == null) return;
    final trimmed = value.trim();
    state = state.copyWith(
      worker: WorkerIdentity(
        workerId: worker.workerId,
        displayName: worker.displayName,
        workerType: worker.workerType,
        source: worker.source,
        contractorCompany: worker.contractorCompany,
        // Typed on this device, so manual — never verified. There is no code
        // path from this screen to a verified value, by construction.
        gatePass: trimmed.isEmpty ? null : EnterpriseValue.manual(trimmed),
      ),
    );
  }

  void setContractorCompany(String value) {
    final worker = state.worker;
    if (worker == null) return;
    final trimmed = value.trim();
    state = state.copyWith(
      worker: WorkerIdentity(
        workerId: worker.workerId,
        displayName: worker.displayName,
        workerType: worker.workerType,
        source: worker.source,
        contractorCompany: trimmed.isEmpty ? null : trimmed,
        gatePass: worker.gatePass,
      ),
    );
  }

  /// Records a permit reference typed on this device.
  ///
  /// [EnterpriseValue.manual] is not a default that could be swapped for
  /// something stronger later by editing this line: a verified value cannot be
  /// constructed without the external system and reference that back it, and
  /// this screen has neither.
  void setPermit({required String reference, PtwType? type}) {
    final trimmed = reference.trim();
    state = state.copyWith(
      permit: trimmed.isEmpty
          ? null
          : PtwReference(
              reference: EnterpriseValue.manual(trimmed),
              type: type ?? state.permit?.type,
            ),
    );
  }

  void setPermitType(PtwType type) {
    final permit = state.permit;
    if (permit == null) return;
    state = state.copyWith(
      permit: PtwReference(reference: permit.reference, type: type),
    );
  }

  void setJsa({required String reference, String? note}) {
    final trimmed = reference.trim();
    state = state.copyWith(
      jsa: trimmed.isEmpty
          ? null
          : JsaReference(
              reference: EnterpriseValue.manual(trimmed),
              note: (note ?? state.jsa?.note)?.trim().isEmpty ?? true
                  ? null
                  : (note ?? state.jsa?.note),
            ),
    );
  }

  /// Records the worker's acknowledgement, or withdraws it.
  ///
  /// There is no stored "false": withdrawing removes the record entirely. A
  /// stored negative would read as "DoseBand asked and was told no", which is
  /// not what an absent acknowledgement means.
  void setToolboxTalk({required bool acknowledged, String? reference}) {
    if (!acknowledged) {
      state = state.copyWith(clearToolboxTalk: true);
      return;
    }
    final trimmed = reference?.trim();
    state = state.copyWith(
      toolboxTalk: ToolboxTalkAcknowledgement(
        acknowledgedAt: DateTime.now(),
        source: EnterpriseDataSource.manualEntry,
        reference: trimmed == null || trimmed.isEmpty ? null : trimmed,
      ),
    );
  }

  /// Fills the form with the demo context, for demonstrations and screenshots.
  ///
  /// Everything it writes carries [EnterpriseDataSource.demo], so a filled form
  /// is visibly demonstration data rather than something that looks typed in.
  void fillWithDemoData(WorkContext demo) =>
      state = WorkContextDraft.from(demo);
}

/// Whether DoseBand has what it needs to begin — and what is missing if not.
///
/// One provider, one rule. Screens read this; none of them re-derive it.
final workContextReadinessProvider = Provider<WorkContextReadiness>((ref) {
  final draft = ref.watch(workContextDraftProvider);
  final session = ref.watch(shiftSessionProvider).value ?? ShiftSession.none;
  return WorkContextValidator.assess(draft, badge: session.assignedBadge);
});
