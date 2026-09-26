import '../domain/work_taxonomy.dart';

/// Where the selectable work-context options come from.
///
/// An interface so that presentation never holds the lists, and so the demo
/// implementation can be replaced by a real one — or by an MRPL integration —
/// without a screen changing. See §23 of the phase brief: this is a seam, not
/// a network client. There is no HTTP here and no endpoint anywhere.
abstract interface class WorkContextRepository {
  List<Department> departments();

  /// Areas configured for [siteId]. Returns an empty list for a site with no
  /// configured areas rather than falling back to another site's.
  List<WorkArea> workAreas(String siteId);

  List<WorkShift> shifts();

  List<PtwType> permitTypes();
}

/// Prototype configuration.
///
/// **NOT FETCHED FROM ANY MRPL SYSTEM.** Every value here is seeded
/// demonstration data for the prototype. It is not a directory, it is not
/// authoritative, and no claim is made that any of it reflects current MRPL
/// configuration.
final class DemoWorkContextRepository implements WorkContextRepository {
  const DemoWorkContextRepository();

  /// A deliberately small subset.
  ///
  /// MRPL has many more departments than this, and the project's research notes
  /// list them. Offering all sixteen in a worker's selector would be worse, not
  /// better: the workers who wear a dosimeter badge are in operational
  /// departments, and a list padded with Legal, Vigilance and Internal Audit
  /// makes the real choice harder to find. Extending it is one line.
  @override
  List<Department> departments() => const [
    Department(id: 'operations', name: 'Operations'),
    Department(id: 'maintenance', name: 'Maintenance'),
    Department(id: 'hse', name: 'Health, Safety & Environment'),
    Department(id: 'projects', name: 'Projects'),
  ];

  /// Demo work areas, keyed by site.
  ///
  /// Refinery unit names are ones MRPL is publicly associated with, suffixed
  /// "— Demo area" so no screenshot can be read as real area configuration.
  ///
  /// There are deliberately no area codes, no zone classifications and no
  /// hazard banding. An area says where the work is; it must never be used to
  /// imply what the atmosphere contains.
  static const Map<String, List<WorkArea>> _areasBySite = {
    'mangalore-refinery': [
      WorkArea(
        id: 'sru',
        name: 'Sulphur Recovery Unit — Demo area',
        siteId: 'mangalore-refinery',
      ),
      WorkArea(
        id: 'pfcc',
        name: 'PFCC — Demo area',
        siteId: 'mangalore-refinery',
      ),
      WorkArea(
        id: 'hydrocracker',
        name: 'Hydrocracker — Demo area',
        siteId: 'mangalore-refinery',
      ),
      WorkArea(
        id: 'delayed-coker',
        name: 'Delayed Coker — Demo area',
        siteId: 'mangalore-refinery',
      ),
      WorkArea(
        id: 'dhds',
        name: 'Diesel Hydro-Desulphurisation — Demo area',
        siteId: 'mangalore-refinery',
      ),
      WorkArea(
        id: 'utilities',
        name: 'Utilities / Offsites — Demo area',
        siteId: 'mangalore-refinery',
      ),
    ],
    'corporate-office': [
      WorkArea(
        id: 'office-block',
        name: 'Office block — Demo area',
        siteId: 'corporate-office',
      ),
    ],
    'retail-hiq': [
      WorkArea(
        id: 'forecourt',
        name: 'Forecourt — Demo area',
        siteId: 'retail-hiq',
      ),
    ],
    'projects-site': [
      WorkArea(
        id: 'construction',
        name: 'Construction front — Demo area',
        siteId: 'projects-site',
      ),
    ],
  };

  @override
  List<WorkArea> workAreas(String siteId) =>
      _areasBySite[siteId]?.where((a) => a.active).toList() ?? const [];

  /// Prototype shifts. MRPL's real scheduling system is not modelled.
  ///
  /// The windows are display strings. Nothing parses them, and nothing may use
  /// them to compute or extend an exposure window — the monitoring timestamps
  /// are the only authority on that.
  @override
  List<WorkShift> shifts() => const [
    WorkShift(id: 'general', name: 'General shift', window: '09:00–17:30'),
    WorkShift(id: 'a', name: 'Shift A', window: '06:00–14:00'),
    WorkShift(id: 'b', name: 'Shift B', window: '14:00–22:00'),
    WorkShift(id: 'c', name: 'Shift C', window: '22:00–06:00'),
  ];

  /// Permit categories offered in the picker.
  ///
  /// **Not claimed to be exhaustive or current.** DoseBand records which
  /// category the worker says their permit falls under; it does not validate
  /// the choice and does not know MRPL's real permit taxonomy.
  @override
  List<PtwType> permitTypes() => const [
    PtwType(id: 'hot-work', name: 'Hot work / vehicle entry'),
    PtwType(id: 'cold-work', name: 'Cold work'),
    PtwType(id: 'height', name: 'Work at height'),
    PtwType(id: 'excavation', name: 'Excavation'),
    PtwType(id: 'radiography', name: 'Radiography'),
    PtwType(id: 'electrical', name: 'Electrical'),
    PtwType(id: 'vessel-entry', name: 'Vessel entry'),
  ];

  /// Resolves a stored identifier back to its configured object.
  ///
  /// Used by the persistence decoder. Returns null for an unknown id, which is
  /// what makes "unknown work area" a refusal rather than a silently dropped
  /// field.
  WorkArea? workAreaById(String id) {
    for (final areas in _areasBySite.values) {
      for (final area in areas) {
        if (area.id == id) return area;
      }
    }
    return null;
  }

  Department? departmentById(String id) {
    for (final d in departments()) {
      if (d.id == id) return d;
    }
    return null;
  }

  WorkShift? shiftById(String id) {
    for (final s in shifts()) {
      if (s.id == id) return s;
    }
    return null;
  }

  PtwType? permitTypeById(String id) {
    for (final t in permitTypes()) {
      if (t.id == id) return t;
    }
    return null;
  }
}
