import 'auth_models.dart';

/// How far a role's view of the organisation reaches (APP-PRODUCT-01 §39).
enum AccessScope {
  /// The signed-in person's own records.
  self,

  /// The workers a supervisor is responsible for.
  team,

  department,
  site,
  organization,
}

/// The three information classes (§5, §40).
enum DataClass {
  /// Name, photo, worker ID, DoseBand assignment, monitoring periods and
  /// identified exposure records, work context.
  identifiedOccupational,

  /// Exposure information with direct identifiers removed, for reporting.
  deidentifiedExposure,

  /// Lots, inventory, devices, versions, configuration, integrations, audit.
  systemOperational,
}

/// What a person may do. Coarse on purpose: this is a design contract for the
/// server to enforce, not a UI permission system (§39).
enum Permission {
  viewOwnProfile,
  viewOwnMonitoring,
  viewOwnHistory,
  claimDoseBand,
  performFinalScan,
  viewTeamIdentities,
  viewTeamMonitoring,
  viewIdentifiedExposures,
  reviewMeasurements,
  recordDisposition,
  viewDeidentifiedReports,
  exportOccupationalReports,
  manageAccounts,
  manageRolesAndScopes,
  manageDoseBandInventory,
  manageDevices,
  manageSystemConfiguration,
  viewSystemAudit,
}

/// The one authorization boundary the UI consults.
///
/// Replaces the pattern of comparing role names in screens (§39). A screen
/// asks `policy.allows(role, Permission.x)`; it never asks which role it is.
///
/// **DESIGN CONTRACT — SERVER ENFORCEMENT PENDING.** No server exists, and a
/// client-side check is not authorization: a modified app can skip it. This
/// interface is the seam a server-backed implementation replaces (P10). Until
/// then, [DesignContractAccessPolicy] states the approved matrix so the UI is
/// built against it, and `docs/product/role-permission-matrix.md` is the
/// human-readable copy.
abstract interface class AccessPolicy {
  bool allows(AppRole role, Permission permission);

  /// The widest scope over which [role] may see [dataClass], or null if it
  /// may not see it at all.
  AccessScope? scopeFor(AppRole role, DataClass dataClass);
}

/// The approved role matrix, as data. See the role-permission matrix document.
final class DesignContractAccessPolicy implements AccessPolicy {
  const DesignContractAccessPolicy();

  static const Map<AppRole, Set<Permission>> _permissions = {
    AppRole.worker: {
      Permission.viewOwnProfile,
      Permission.viewOwnMonitoring,
      Permission.viewOwnHistory,
      Permission.claimDoseBand,
      Permission.performFinalScan,
    },
    AppRole.supervisor: {
      Permission.viewOwnProfile,
      Permission.viewTeamIdentities,
      Permission.viewTeamMonitoring,
      // Identified exposure information, within the supervisory scope only —
      // see [_scopes].
      Permission.viewIdentifiedExposures,
    },
    AppRole.hseOfficer: {
      Permission.viewOwnProfile,
      Permission.viewIdentifiedExposures,
      Permission.reviewMeasurements,
      Permission.recordDisposition,
      Permission.viewDeidentifiedReports,
      Permission.exportOccupationalReports,
    },
    AppRole.management: {
      Permission.viewOwnProfile,
      Permission.viewDeidentifiedReports,
    },
    // SYSTEM ADMIN != HSE OFFICER (§124). Administering the software grants
    // no identified occupational exposure access.
    AppRole.administrator: {
      Permission.viewOwnProfile,
      Permission.manageAccounts,
      Permission.manageRolesAndScopes,
      Permission.manageDoseBandInventory,
      Permission.manageDevices,
      Permission.manageSystemConfiguration,
      Permission.viewSystemAudit,
    },
  };

  static const Map<AppRole, Map<DataClass, AccessScope>> _scopes = {
    AppRole.worker: {DataClass.identifiedOccupational: AccessScope.self},
    AppRole.supervisor: {DataClass.identifiedOccupational: AccessScope.team},
    AppRole.hseOfficer: {
      // Within the HSE officer's authorised scope — a site by default. The
      // server decides which site.
      DataClass.identifiedOccupational: AccessScope.site,
      DataClass.deidentifiedExposure: AccessScope.site,
    },
    AppRole.management: {
      DataClass.deidentifiedExposure: AccessScope.organization,
    },
    AppRole.administrator: {
      DataClass.systemOperational: AccessScope.organization,
    },
  };

  @override
  bool allows(AppRole role, Permission permission) =>
      _permissions[role]!.contains(permission);

  @override
  AccessScope? scopeFor(AppRole role, DataClass dataClass) =>
      _scopes[role]![dataClass];
}
