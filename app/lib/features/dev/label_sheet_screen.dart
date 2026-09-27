import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/product_page.dart';
import '../../core/components/workspace_components.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/domain/doseband.dart';
import '../admin/presentation/admin_workspace.dart';
import '../operations/application/operations_repository.dart';

/// Development only: QR labels for the presentation inventory's available
/// DoseBands, to print or show on a second screen for the scanner.
///
/// A label identifies a band; it is not a badge. The optical pre-use check
/// and the final scan still need the printed DoseBand target.
class LabelSheetScreen extends ConsumerWidget {
  const LabelSheetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ProductPage(
    title: 'DoseBand QR labels',
    children: [
      OpsView(
        value: ref.watch(operationsProvider),
        builder: (context, s) {
          final bands =
              s.bands.values
                  .where((b) => b.lifecycle == DoseBandLifecycle.available)
                  .toList()
                ..sort((a, b) => a.dosebandId.compareTo(b.dosebandId));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${bands.length} available DoseBands, including ones from '
                'expired and unsupported lots so the pre-use check can be '
                'shown refusing them.',
                style: context.type.caption.copyWith(
                  color: context.product.textSecondary,
                ),
              ),
              const SizedBox(height: Space.base),
              Wrap(
                spacing: Space.base,
                runSpacing: Space.base,
                children: [
                  for (final b in bands)
                    QrLabel(dosebandId: b.dosebandId, size: 128),
                ],
              ),
            ],
          );
        },
      ),
    ],
  );
}
