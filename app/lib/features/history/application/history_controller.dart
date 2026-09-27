import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../operations/application/operations_providers.dart';
import '../domain/measurement_record.dart';

/// The signed-in worker's measurement history, newest first.
///
/// Two sources, kept apart on purpose:
///
/// * the worker's own records in the operations store — persisted, and the
///   same records the supervisor and HSE see;
/// * records from the development simulation, held in memory only and
///   marked simulated. They are never written to the store: a simulated
///   specimen must not enter the organisation's records (§25, §138).
///
/// No fake records are seeded; an empty history is a true empty history.
final historyProvider = Provider<List<MeasurementRecord>>((ref) {
  final own = ref.watch(workerViewProvider).value?.history() ?? const [];
  final simulated = ref.watch(simulatedHistoryProvider);
  return [...own, ...simulated]
    ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
});

/// Development-simulation records, in memory.
final simulatedHistoryProvider =
    NotifierProvider<SimulatedHistory, List<MeasurementRecord>>(
      SimulatedHistory.new,
    );

class SimulatedHistory extends Notifier<List<MeasurementRecord>> {
  @override
  List<MeasurementRecord> build() => const [];

  void add(MeasurementRecord record) => state = [record, ...state];
}
