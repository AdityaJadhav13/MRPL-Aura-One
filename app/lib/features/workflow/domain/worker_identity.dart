import 'package:flutter/foundation.dart';

import 'enterprise_value.dart';

/// Whether the worker is employed by the organisation or by a contractor.
///
/// Declared here rather than reused from the authentication feature on purpose.
/// This value becomes measurement provenance: it is written into a monitoring
/// record that must still be readable and meaningful long after the sign-in
/// screen has been redesigned or replaced. Coupling stored provenance to a UI
/// enum would make a presentation change a data-migration event.
enum WorkerType {
  employee('Employee'),
  contractor('Contractor');

  const WorkerType(this.label);

  final String label;
}

/// Who a monitored period belongs to.
///
/// A **snapshot**, not a live view of whoever happens to be signed in. It is
/// captured when the work context is committed and never re-derived, because a
/// different worker signing in afterwards must not silently rewrite the
/// provenance of an exposure record that already exists.
@immutable
final class WorkerIdentity {
  const WorkerIdentity({
    required this.workerId,
    required this.displayName,
    required this.workerType,
    required this.source,
    this.contractorCompany,
    this.gatePass,
  });

  final String workerId;
  final String displayName;
  final WorkerType workerType;

  /// Where the identity itself came from. Today always
  /// [EnterpriseDataSource.demo] — no identity provider is connected.
  final EnterpriseDataSource source;

  /// The employing contractor. Required for [WorkerType.contractor] and absent
  /// for an employee; see [contractorCompanyIsCoherent].
  final String? contractorCompany;

  /// Gate-pass identifier, if one has been recorded.
  ///
  /// Never verified today. A gate pass is issued by MRPL's security process,
  /// so a value typed into this app is a claim about a credential, not the
  /// credential itself, and it is carried as an [EnterpriseValue] so that
  /// stays visible.
  final EnterpriseValue<String>? gatePass;

  /// A contractor without a company, or an employee with one, is incoherent.
  ///
  /// Enforced at the edges rather than in the constructor so that a
  /// half-filled form can be *described* (and its problem reported to the
  /// worker) without being constructible as a committed identity. The
  /// validator and the persistence decoder both consult this.
  bool get contractorCompanyIsCoherent => switch (workerType) {
    WorkerType.contractor =>
      contractorCompany != null && contractorCompany!.trim().isNotEmpty,
    WorkerType.employee => contractorCompany == null,
  };

  @override
  bool operator ==(Object other) =>
      other is WorkerIdentity &&
      other.workerId == workerId &&
      other.displayName == displayName &&
      other.workerType == workerType &&
      other.source == source &&
      other.contractorCompany == contractorCompany &&
      other.gatePass == gatePass;

  @override
  int get hashCode => Object.hash(
    workerId,
    displayName,
    workerType,
    source,
    contractorCompany,
    gatePass,
  );
}
