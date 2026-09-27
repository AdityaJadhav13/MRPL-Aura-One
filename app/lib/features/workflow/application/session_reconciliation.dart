import '../../../core/domain/monitoring_session.dart';
import '../../operations/domain/operations_snapshot.dart';
import '../data/work_context_repository.dart';
import '../domain/enterprise_value.dart';
import '../domain/permit_context.dart';
import '../domain/physical_badge.dart';
import '../domain/work_context.dart';
import '../domain/work_taxonomy.dart';
import '../domain/worker_identity.dart';
import '../domain/workflow_state.dart';

/// Keeps the worker's device session and the operations store telling the
/// same story (PRODUCT BUILD v1 §14, §48).
///
/// The operations store is authoritative for *organisational* state: whether
/// a band is claimed, whether a period is open, whether it was read. The
/// device session holds the worker's journey through it — the full work
/// context, the band's identity, the result to show. They are written in that
/// order, so after a crash the store may be one step ahead and never behind.
///
/// On load the device session is reconciled against the store:
///
/// * the store has an open period the device does not know (another device,
///   a reinstall, the presentation dataset) → the device session is rebuilt
///   from the store;
/// * the device thinks a period is open that the store has closed (a
///   supervisor closed it as "final scan missing", the band was reported
///   lost) → the device session is cleared;
/// * otherwise the device session stands.
///
/// A simulated development session has no store record and is left alone.
abstract final class SessionReconciliation {
  static ShiftSession reconcile({
    required ShiftSession local,
    required OperationsSnapshot snapshot,
    required String workerId,
  }) {
    final active = snapshot.activeAssignmentOf(workerId);
    final open = active == null ? null : snapshot.session(active.sessionId);

    if (open != null) {
      if (local.sessionId == open.sessionId) return _align(local, open);
      return _fromStore(snapshot, open, workerId) ?? local;
    }

    final id = local.sessionId;
    if (id == null || local.stage == ShiftStage.complete) return local;
    final closed = snapshot.session(id);
    if (closed == null) return ShiftSession.none;
    final m = closed.measurementId == null
        ? null
        : snapshot.measurement(closed.measurementId!);
    if (m != null) {
      // The record was written and the device session was not: finish it.
      return local.copyWith(
        stage: ShiftStage.complete,
        startedAt: closed.startedAt,
        endedAt: closed.endedAt,
        result: m.result,
        captureId: m.captureId,
      );
    }
    // Closed elsewhere without a reading. Nothing on this device is open.
    return ShiftSession.none;
  }

  /// Brings a device session level with the store's timestamps and state for
  /// the same period.
  static ShiftSession _align(ShiftSession local, MonitoringSession open) {
    final stage = switch (open.state) {
      MonitoringSessionState.active ||
      MonitoringSessionState.partial => ShiftStage.monitoring,
      MonitoringSessionState.readyForFinalRead => ShiftStage.awaitingScan,
      _ => local.stage,
    };
    if (stage == local.stage &&
        open.startedAt == local.startedAt &&
        open.endedAt == local.endedAt) {
      return local;
    }
    return ShiftSession(
      stage: stage,
      context: local.context,
      physicalBadge: local.physicalBadge,
      badge: local.badge,
      startedAt: open.startedAt ?? local.startedAt,
      endedAt: stage == ShiftStage.awaitingScan ? open.endedAt : null,
      captureId: local.captureId,
      sessionId: local.sessionId,
      assignmentId: local.assignmentId,
    );
  }

  static ShiftSession? _fromStore(
    OperationsSnapshot s,
    MonitoringSession open,
    String workerId,
  ) {
    final stage = switch (open.state) {
      MonitoringSessionState.active ||
      MonitoringSessionState.partial => ShiftStage.monitoring,
      MonitoringSessionState.readyForFinalRead => ShiftStage.awaitingScan,
      _ => null,
    };
    final band = open.dosebandId == null ? null : s.bands[open.dosebandId];
    final assignment = open.assignmentId == null
        ? null
        : s.assignment(open.assignmentId!);
    final context = contextFromStore(s, open, workerId);
    if (stage == null ||
        band == null ||
        assignment == null ||
        context == null ||
        open.startedAt == null) {
      return null;
    }
    return ShiftSession(
      stage: stage,
      context: context,
      physicalBadge: PhysicalBadge(
        badgeId: band.dosebandId,
        batchId: band.lotId,
        formulationId: band.formulationId,
        expiresOn: s.lot(band.lotId)?.expiresOn,
        source: BadgeIdentitySource.localRegistry,
        identifiedAt: assignment.claimedAt,
      ),
      startedAt: open.startedAt,
      endedAt: stage == ShiftStage.awaitingScan ? open.endedAt : null,
      sessionId: open.sessionId,
      assignmentId: assignment.assignmentId,
    );
  }

  /// Rebuilds a work context from what the store recorded for the period.
  ///
  /// The store keeps a summary — site, department, area, shift, activity —
  /// not the permit and JSA references, which were typed on the device that
  /// started the period. Those come back saying exactly that, marked as
  /// presentation data; nothing is invented to fill them.
  static WorkContext? contextFromStore(
    OperationsSnapshot s,
    MonitoringSession open,
    String workerId,
  ) {
    final person = s.person(workerId);
    final work = open.work;
    if (person == null || work == null) return null;
    const repo = DemoWorkContextRepository();
    const notHere = 'Not recorded on this device';
    final area =
        repo.workAreaById(work.workAreaId ?? '') ??
        WorkArea(
          id: work.workAreaId ?? 'unrecorded',
          name: work.workAreaName ?? 'Not recorded',
          siteId: work.siteId,
        );
    return WorkContext(
      worker: WorkerIdentity(
        workerId: person.personId,
        displayName: person.displayName,
        workerType: person.workerType,
        source: EnterpriseDataSource.demo,
        contractorCompany: person.contractorCompany,
      ),
      site: SiteRef(id: work.siteId, name: work.siteName),
      department: Department(id: work.departmentId, name: work.departmentName),
      workArea: area,
      shift:
          repo.shiftById(work.shiftId ?? '') ??
          WorkShift(
            id: work.shiftId ?? 'unrecorded',
            name: work.shiftName ?? 'Not recorded',
          ),
      job: JobContext(title: work.activity ?? notHere),
      permit: const PtwReference(reference: EnterpriseValue.demo(notHere)),
      jsa: const JsaReference(reference: EnterpriseValue.demo(notHere)),
      toolboxTalk: ToolboxTalkAcknowledgement(
        acknowledgedAt: open.startedAt ?? s.seededAt,
        source: EnterpriseDataSource.demo,
      ),
    );
  }

  /// The organisational summary of a work context.
  static WorkSummary summaryOf(WorkContext c) => WorkSummary(
    siteId: c.site.id,
    siteName: c.site.name,
    departmentId: c.department.id,
    departmentName: c.department.name,
    workAreaId: c.workArea.id,
    workAreaName: c.workArea.name,
    shiftId: c.shift.id,
    shiftName: c.shift.name,
    activity: c.job.title,
  );
}
