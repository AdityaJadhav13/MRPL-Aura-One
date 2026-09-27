import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/operations_snapshot.dart';
import 'access.dart';
import 'admin_service.dart';
import 'hse_service.dart';
import 'management_service.dart';
import 'operations_repository.dart';
import 'supervisor_service.dart';
import 'worker_service.dart';

/// A view of the operations store for the signed-in actor.
///
/// Loading while the store opens; an [AccessDenied] error when the actor may
/// not have this view — a screen renders that as "permission denied", never
/// as an empty list that would look like "no records".
Provider<AsyncValue<T>> _viewOf<T>(
  T Function(OperationsSnapshot s, Actor a) make,
) => Provider<AsyncValue<T>>((ref) {
  final snapshot = ref.watch(operationsProvider);
  final actor = ref.watch(currentActorProvider);
  return snapshot.when(
    loading: () => const AsyncLoading(),
    error: (e, st) => AsyncError(e, st),
    data: (s) {
      if (actor == null) {
        return AsyncError(
          const AccessDenied('Sign in to see this.'),
          StackTrace.current,
        );
      }
      try {
        return AsyncData(make(s, actor));
      } on AccessDenied catch (e, st) {
        return AsyncError(e, st);
      }
    },
  );
});

final workerViewProvider = _viewOf(WorkerView.new);
final ownProfileProvider = _viewOf(OwnProfileView.new);
final supervisorViewProvider = _viewOf(SupervisorView.new);
final hseViewProvider = _viewOf(HseView.new);
final managementViewProvider = _viewOf(ManagementView.new);
final adminViewProvider = _viewOf(AdminView.new);

Actor _requireActor(Ref ref) =>
    ref.watch(currentActorProvider) ??
    (throw const AccessDenied('Sign in first.'));

final workerCommandsProvider = Provider<WorkerCommands>(
  (ref) => WorkerCommands(
    repository: ref.watch(operationsProvider.notifier),
    actor: _requireActor(ref),
    ids: ref.watch(idGeneratorProvider),
    now: ref.watch(clockProvider),
  ),
);

final supervisorCommandsProvider = Provider<SupervisorCommands>(
  (ref) => SupervisorCommands(
    repository: ref.watch(operationsProvider.notifier),
    actor: _requireActor(ref),
    ids: ref.watch(idGeneratorProvider),
    now: ref.watch(clockProvider),
  ),
);

final hseCommandsProvider = Provider<HseCommands>(
  (ref) => HseCommands(
    repository: ref.watch(operationsProvider.notifier),
    actor: _requireActor(ref),
    ids: ref.watch(idGeneratorProvider),
    now: ref.watch(clockProvider),
  ),
);

final adminCommandsProvider = Provider<AdminCommands>(
  (ref) => AdminCommands(
    repository: ref.watch(operationsProvider.notifier),
    actor: _requireActor(ref),
    ids: ref.watch(idGeneratorProvider),
    now: ref.watch(clockProvider),
  ),
);
