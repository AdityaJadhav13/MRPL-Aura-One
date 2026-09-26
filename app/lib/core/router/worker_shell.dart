import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../components/product_navigation.dart';

/// The worker shell: Home · History · **Scan** · Safety · Profile.
///
/// The approved worker navigation (APP-PRODUCT-01 §6). Scan sits in the
/// centre as the dominant control, because it is the one physical thing a
/// worker does with DoseBand. What Scan *does* — claim a new DoseBand, show
/// the active monitoring, read the assigned band — is decided by the Scan
/// screen from the worker's state, not by the bar (§58).
///
/// This replaces the four-destination bar of UI-SURFACE-01, where account sat
/// behind the Home header avatar. Profile is now a destination because the
/// approved product gives the worker an identity surface of their own (P1),
/// not a settings page hidden behind a picture.
///
/// Permit, JSA, DoseBand and occupational-health screens are still reached
/// from the work they belong to, not from a tab: they are steps in a task, and
/// a task step promoted to a destination loses its place in the sequence.
class WorkerShell extends StatelessWidget {
  const WorkerShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return AdaptiveNavigationScaffold(
      destinations: WorkspaceDestinations.worker,
      selectedIndex: shell.currentIndex,
      // Re-selecting the current destination returns it to its root, which is
      // what a worker expects after drilling into something.
      onSelected: (i) =>
          shell.goBranch(i, initialLocation: i == shell.currentIndex),
      body: shell,
    );
  }
}
