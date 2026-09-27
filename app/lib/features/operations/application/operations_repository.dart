import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../data/operations_store.dart';
import '../data/presentation_dataset.dart';
import '../domain/operations_snapshot.dart';

/// Where the operations snapshot is persisted. Overridden at the application
/// root with the file store, and in tests with an in-memory one.
final operationsStoreProvider = Provider<OperationsStore>(
  (_) => InMemoryOperationsStore(),
);

/// Identifier source, injectable so tests are deterministic.
final idGeneratorProvider = Provider<IdGenerator>(
  (ref) => RandomIdGenerator(now: ref.watch(clockProvider)),
);

abstract interface class IdGenerator {
  /// A new identifier with [prefix], unique on this device.
  String next(String prefix);
}

/// Time-ordered, counted and random: `SES-lz3k9q-1-7f2a9c01`. The counter
/// makes identifiers unique within this process even when the clock does not
/// move between two calls; the random part separates devices. A central
/// server would issue its own and keep these as idempotency keys (§53).
final class RandomIdGenerator implements IdGenerator {
  RandomIdGenerator({required this.now, Random? random})
    : _random = random ?? Random.secure();

  final DateTime Function() now;
  final Random _random;
  int _counter = 0;

  @override
  String next(String prefix) {
    final t = now().microsecondsSinceEpoch.toRadixString(36);
    final n = (++_counter).toRadixString(36);
    final r = _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return '$prefix-$t-$n-$r';
  }
}

/// Counts up. For tests and goldens.
final class SequentialIdGenerator implements IdGenerator {
  int _n = 0;

  @override
  String next(String prefix) => '$prefix-${(++_n).toString().padLeft(4, '0')}';
}

/// The operations snapshot, and the only way to change it.
final operationsProvider =
    AsyncNotifierProvider<OperationsRepository, OperationsSnapshot>(
      OperationsRepository.new,
    );

/// The result of one transaction body: the next snapshot and what to return.
typedef Transaction<R> = ({OperationsSnapshot next, R result});

/// Holds the snapshot and serialises every change to it.
///
/// ## Atomicity — and its limit
///
/// Every mutation runs as a [transact] body against the latest snapshot, one
/// at a time, and is written to the store before the new state is exposed.
/// Two claims of the same DoseBand therefore cannot both succeed *on this
/// device*: the second body sees the first one's result.
///
/// That is the whole guarantee. Two phones each hold their own store, and
/// nothing here can see the other one. Cross-device uniqueness needs the
/// central server's transactional claim, which is NOT CONNECTED.
class OperationsRepository extends AsyncNotifier<OperationsSnapshot> {
  Future<void> _tail = Future<void>.value();

  OperationsStore get _store => ref.read(operationsStoreProvider);

  @override
  Future<OperationsSnapshot> build() async {
    final loaded = await _store.load();
    if (loaded != null) return loaded;
    final seeded = PresentationDataset.build(ref.read(clockProvider)());
    await _store.save(seeded);
    return seeded;
  }

  /// The snapshot once loaded. For services outside the notifier.
  Future<OperationsSnapshot> current() => future;

  /// Runs [body] against the current snapshot, alone.
  ///
  /// A body that throws changes nothing. A body that returns the snapshot it
  /// was given (identically) writes nothing.
  Future<R> transact<R>(
    Transaction<R> Function(OperationsSnapshot current) body,
  ) {
    final done = Completer<R>();
    _tail = _tail.then((_) async {
      try {
        final current = await future;
        final out = body(current);
        if (!identical(out.next, current)) {
          await _store.save(out.next);
          state = AsyncData(out.next);
        }
        done.complete(out.result);
      } on Object catch (e, st) {
        done.completeError(e, st);
      }
    });
    return done.future;
  }

  /// Discards the store and seeds the presentation dataset again. Offered
  /// only where simulation is available (never in production).
  Future<void> resetPresentationData() {
    final done = Completer<void>();
    _tail = _tail.then((_) async {
      try {
        final seeded = PresentationDataset.build(ref.read(clockProvider)());
        await _store.save(seeded);
        state = AsyncData(seeded);
        done.complete();
      } on Object catch (e, st) {
        done.completeError(e, st);
      }
    });
    return done.future;
  }
}
