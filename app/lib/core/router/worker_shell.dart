import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../components/corporate_navigation.dart';

/// The worker shell: four destinations, always visible.
///
/// Home, Scan, Safety, History — and deliberately nothing else. A worker on a
/// plant has one badge and one shift, and every tab added here is one more
/// thing to read past while wearing gloves.
///
/// Account and settings sit behind the header avatar rather than taking a
/// quarter of the bar. Permit, JSA, badge and occupational-health screens are
/// reached from the work they belong to, not from a global tab: they are steps
/// in a task, and a task step promoted to a destination loses its place in the
/// sequence.
class WorkerShell extends StatelessWidget {
  const WorkerShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  static const _destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.qr_code_scanner_outlined),
      selectedIcon: Icon(Icons.qr_code_scanner),
      label: 'Scan',
    ),
    NavigationDestination(
      icon: Icon(Icons.health_and_safety_outlined),
      selectedIcon: Icon(Icons.health_and_safety),
      label: 'Safety',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long),
      label: 'History',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Worker Home is a corporate surface, not a measurement one, so its
    // navigation is MRPL green rather than the instrument accent. The
    // measurement screens it pushes stay neutral.
    return CorporateNavigationTheme(
      onDark: true,
      child: Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          destinations: _destinations,
          onDestinationSelected: (i) {
            HapticFeedback.selectionClick();
            shell.goBranch(i, initialLocation: i == shell.currentIndex);
          },
        ),
      ),
    );
  }
}
