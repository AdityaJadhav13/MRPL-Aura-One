import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/corporate_navigation.dart';
import '../../../core/design/theme.dart';

/// The HSE officer's shell.
///
/// Four destinations, matching how the job is actually done: see the state of
/// the site, see who is currently wearing a badge, look through the register,
/// and work the queue of records that need a decision.
///
/// ## Why this is not the worker's shell
///
/// A worker has one badge and one shift. An HSE officer has a site. Reusing
/// Home / Scan / Safety / History would give them a Scan tab they will never
/// press and no way to reach the queue that is their actual work.
///
/// On wider layouts the bar becomes a rail: an HSE officer is as likely to be
/// at a desk as on the plant, and a 900-pixel-wide window with a phone bottom
/// bar looks like a scaled-up phone app rather than a tool.
class HseShell extends StatelessWidget {
  const HseShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  /// The width at which a rail becomes better than a bottom bar. Chosen to sit
  /// above every phone in portrait and below a tablet in landscape.
  static const double railBreakpoint = 720;

  static const _destinations = <_Destination>[
    _Destination(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Overview',
    ),
    _Destination(
      icon: Icons.monitor_heart_outlined,
      selectedIcon: Icons.monitor_heart,
      label: 'Monitoring',
    ),
    _Destination(
      icon: Icons.table_chart_outlined,
      selectedIcon: Icons.table_chart,
      label: 'Exposures',
    ),
    _Destination(
      icon: Icons.rule_outlined,
      selectedIcon: Icons.rule,
      label: 'Review',
    ),
  ];

  void _select(int index) {
    HapticFeedback.selectionClick();
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;

    return CorporateNavigationTheme(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useRail = constraints.maxWidth >= railBreakpoint;

          if (useRail) {
            return Scaffold(
              backgroundColor: corporate.surfaceMuted,
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: shell.currentIndex,
                    onDestinationSelected: _select,
                    labelType: NavigationRailLabelType.all,
                    backgroundColor: corporate.surface,
                    indicatorColor: corporate.selectedFill,
                    destinations: [
                      for (final d in _destinations)
                        NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: Text(d.label),
                        ),
                    ],
                  ),
                  VerticalDivider(width: 1, color: corporate.border),
                  Expanded(child: shell),
                ],
              ),
            );
          }

          return Scaffold(
            backgroundColor: corporate.surfaceMuted,
            body: shell,
            bottomNavigationBar: NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _select,
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
