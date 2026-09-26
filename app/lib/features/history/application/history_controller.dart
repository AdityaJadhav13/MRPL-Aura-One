import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/measurement_record.dart';

/// The measurement history.
///
/// Starts empty — no fake production exposure records are ever seeded
/// (directive §65). The simulated worker journey populates it, so the empty
/// state is real and the records that appear are genuinely the ones the demo
/// produced, each in the simulated domain and marked as such.
///
/// In-memory for now; Phase 6 moves it behind the persistent store.
final historyProvider =
    NotifierProvider<HistoryController, List<MeasurementRecord>>(
      HistoryController.new,
    );

class HistoryController extends Notifier<List<MeasurementRecord>> {
  @override
  List<MeasurementRecord> build() => const [];

  void add(MeasurementRecord record) {
    // Newest first.
    state = [record, ...state];
  }

  MeasurementRecord? byId(String id) {
    for (final r in state) {
      if (r.id == id) return r;
    }
    return null;
  }
}
