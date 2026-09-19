import 'package:flutter/material.dart';

import '../../core/components/buttons.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';

/// Scan. Phase 3 replaces this with the camera and guidance overlay.
class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final t = context.type;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan')),
      body: Padding(
        padding: const EdgeInsets.all(Space.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, size: 48, color: c.textSecondary),
            const SizedBox(height: Space.base),
            Text(
              'Camera arrives in Phase 3',
              style: t.heading.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: Space.sm),
            Text(
              'Badge identification and the guided capture flow are not built '
              'yet. Nothing here can produce a reading.',
              style: t.body.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: Space.lg),
            DoseBandButton.secondary(
              label: 'Enter badge ID by hand',
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
