import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../components/product_navigation.dart';

/// One shell for every workspace (PRODUCT BUILD v1 §80, §139): the floating
/// bar on a phone, the rail from the expanded breakpoint, with each role's
/// own destinations. Five workspaces, one application — not five
/// mini-apps with five navigation implementations.
class WorkspaceShell extends StatelessWidget {
  const WorkspaceShell({
    required this.destinations,
    required this.shell,
    super.key,
  });

  final List<ProductDestination> destinations;
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return AdaptiveNavigationScaffold(
      destinations: destinations,
      selectedIndex: shell.currentIndex,
      // Re-selecting the current destination returns it to its root, which is
      // what anyone expects after drilling into something.
      onSelected: (i) =>
          shell.goBranch(i, initialLocation: i == shell.currentIndex),
      body: shell,
    );
  }
}
