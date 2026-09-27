import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/product_page.dart';
import '../../core/components/workspace_components.dart';
import '../../core/design/theme.dart';
import '../operations/application/operations_providers.dart';
import '../result/measurement_detail_screen.dart';
import 'domain/measurement_record.dart';

/// `/history/record/:id` — one of the worker's own records.
///
/// Resolved from the identifier through the worker's view, so a deep link
/// works after a cold start and a link to someone else's record is refused
/// (§87, §145). A simulated record from the development tools is carried in
/// the route's `extra` — it is never in the store — and only accepted when
/// it is simulated and its id matches.
class WorkerRecordRoute extends ConsumerWidget {
  const WorkerRecordRoute({required this.recordId, this.carried, super.key});

  final String recordId;
  final Object? carried;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = carried;
    if (c is MeasurementRecord && c.id == recordId && c.badge.isSimulated) {
      return InstrumentTheme(child: MeasurementDetailScreen(record: c));
    }
    final record = ref
        .watch(workerViewProvider)
        .whenData((v) => v.record(recordId));
    return record.hasValue
        ? InstrumentTheme(child: MeasurementDetailScreen(record: record.value!))
        : ProductPage(
            title: 'Record',
            children: [
              OpsView(value: record, builder: (_, _) => const SizedBox()),
            ],
          );
  }
}
