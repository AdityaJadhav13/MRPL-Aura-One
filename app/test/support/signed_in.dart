import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:h2s_doseband/core/domain/doseband.dart';
import 'package:h2s_doseband/core/router/route_gate.dart';
import 'package:h2s_doseband/core/time/clock.dart';
import 'package:h2s_doseband/features/auth/application/auth_controller.dart';
import 'package:h2s_doseband/features/auth/domain/auth_models.dart';
import 'package:h2s_doseband/features/operations/application/operations_repository.dart';
import 'package:h2s_doseband/features/operations/data/operations_store.dart';
import 'package:h2s_doseband/features/operations/data/presentation_dataset.dart';
import 'package:h2s_doseband/features/operations/domain/operations_snapshot.dart';

/// An auth controller already signed in as [session]. Sign-in itself is
/// covered by the auth tests; everything else starts past it.
class SignedInAs extends AuthController {
  SignedInAs(this.session);

  final AppSession session;

  @override
  AuthState build() => AuthState(status: AuthStatus.signedIn, session: session);
}

/// A presentation account's session in [role] (default: its first).
AppSession presentationSession(String personId, {AppRole? role}) {
  final p = PresentationDataset.people.firstWhere(
    (x) => x.personId == personId,
  );
  return AppSession(
    personId: p.personId,
    displayName: p.displayName,
    roles: p.roles,
    activeRole: role ?? p.roles.first,
    source: AuthSource.demo,
  );
}

/// The presentation dataset with nobody part-way through a period: every
/// band available, no assignments, no sessions. For screens that start a
/// period from scratch.
OperationsSnapshot quietDataset(DateTime now) {
  final s = PresentationDataset.build(now);
  return s.copyWith(
    assignments: const [],
    sessions: const [],
    bands: {
      for (final e in s.bands.entries)
        e.key: DoseBand(
          dosebandId: e.value.dosebandId,
          lifecycle: DoseBandLifecycle.available,
          provenance: e.value.provenance,
          lotId: e.value.lotId,
          formulationId: e.value.formulationId,
          expiry: e.value.expiry,
          geometryVersion: e.value.geometryVersion,
        ),
    },
  );
}

/// Overrides that put a test signed in as [personId], over an operations
/// store seeded with [seed] (default: [quietDataset]) at [now].
List<Override> signedInOverrides({
  required String personId,
  AppRole? role,
  OperationsSnapshot? seed,
  DateTime? now,
  OperationsStore? store,
}) {
  final t = now ?? DateTime(2026, 9, 27, 10, 30);
  return [
    authControllerProvider.overrideWith(
      () => SignedInAs(presentationSession(personId, role: role)),
    ),
    operationsStoreProvider.overrideWithValue(
      store ?? InMemoryOperationsStore(seed ?? quietDataset(t)),
    ),
    idGeneratorProvider.overrideWithValue(SequentialIdGenerator()),
    clockProvider.overrideWithValue(() => t),
  ];
}

/// Who a route sweep signs in as: the account whose workspace the route
/// belongs to, so every screen renders with the data its role would see.
/// Shared routes (splash, sign-in, developer tools) run as the worker.
String personForRoute(String route) => switch (RouteGate.workspaceOf(route)) {
  AppRole.supervisor => PresentationDataset.aman,
  AppRole.hseOfficer => PresentationDataset.samhita,
  AppRole.management || AppRole.administrator => PresentationDataset.yashvi,
  AppRole.worker || null => PresentationDataset.aditya,
};

/// Overrides for sweeping [route]: signed in as its owner, over the full
/// presentation dataset.
List<Override> routeOverrides(String route, {DateTime? now}) {
  final t = now ?? DateTime(2026, 9, 27, 10, 30);
  return signedInOverrides(
    personId: personForRoute(route),
    role: RouteGate.workspaceOf(route),
    seed: PresentationDataset.build(t),
    now: t,
  );
}
