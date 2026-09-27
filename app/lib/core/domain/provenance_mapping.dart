import 'package:measurement/measurement.dart';

import '../../features/workflow/domain/enterprise_value.dart';
import '../../features/workflow/domain/physical_badge.dart';
import '../components/corporate.dart';
import 'provenance.dart';

/// Every existing provenance type, mapped into the one product vocabulary.
///
/// Each mapping is an exhaustive `switch`, so a value added to any source enum
/// is a compile error here until someone decides what it means.

extension DataDomainProvenance on DataDomain {
  /// A measurement's data domain. `lab` is controlled evidence produced on
  /// this device; it is real, but it is not a field dose — the measurement
  /// package's `mayProduceWorkerFacingDose` still decides that, not this.
  RecordProvenance get provenance => switch (this) {
    DataDomain.simulated => RecordProvenance.simulated,
    DataDomain.lab => RecordProvenance.realLocal,
    DataDomain.field => RecordProvenance.realLocal,
  };
}

extension DataOriginProvenance on DataOrigin {
  RecordProvenance get provenance => switch (this) {
    DataOrigin.real => RecordProvenance.realLocal,
    DataOrigin.uiDemo => RecordProvenance.presentationSeeded,
    DataOrigin.notConnected => RecordProvenance.notConnected,
  };
}

extension EnterpriseSourceProvenance on EnterpriseDataSource {
  RecordProvenance get provenance => switch (this) {
    EnterpriseDataSource.demo => RecordProvenance.presentationSeeded,
    EnterpriseDataSource.manualEntry => RecordProvenance.manualEntry,
    EnterpriseDataSource.organizationIntegration =>
      RecordProvenance.organizationIntegration,
  };
}

extension BadgeIdentitySourceProvenance on BadgeIdentitySource {
  RecordProvenance get provenance => switch (this) {
    BadgeIdentitySource.manualEntry => RecordProvenance.manualEntry,
    // The identity is whatever the local inventory holds, and that inventory
    // is the presentation dataset until a server supplies one.
    BadgeIdentitySource.localRegistry => RecordProvenance.presentationSeeded,
  };
}
