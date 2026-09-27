import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../components/product_navigation.dart';
import 'workspace_shell.dart';

/// The worker's shell: Home · History · Scan · Safety · Profile.
class WorkerShell extends StatelessWidget {
  const WorkerShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) =>
      WorkspaceShell(destinations: WorkspaceDestinations.worker, shell: shell);
}
