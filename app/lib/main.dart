import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/design/theme.dart';
import 'core/dev/home_state_preview.dart';
import 'core/env/environment.dart';
import 'core/router/app_router.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/workflow/application/workflow_controller.dart';
import 'features/workflow/data/file_workflow_store.dart';
import 'features/workflow/data/workflow_store.dart';

/// Default entry point for a bare `flutter run` (which targets `lib/main.dart`).
///
/// It boots the dev flavour so the app launches without extra arguments. The
/// per-flavour `main_*.dart` files remain the explicit way to select an
/// environment; they and this default both funnel through [bootstrap], so there
/// is still exactly one startup path.
void main() => bootstrap(EnvironmentConfig.fromDartDefines(AppEnvironment.dev));

/// Shared entry point. The per-flavour `main_*.dart` files each call this with
/// their own configuration, so there is exactly one startup path.
Future<void> bootstrap(EnvironmentConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Opened before the first frame. The router's first decision depends on
  // whether a monitored period is already in progress, and a worker must never
  // see "no active monitoring" for a few frames while storage is read — that
  // reads as "the app lost my shift", which is the exact failure this store
  // exists to prevent.
  //
  // A store that cannot be opened at all (a full or read-only filesystem)
  // falls back to the in-memory one: the app still runs the period, and only
  // loses it on a cold start, which is no worse than before persistence
  // existed. It must not be a launch failure.
  WorkflowStore store;
  try {
    store = await FileWorkflowStore.open();
  } on Object catch (error, stack) {
    debugPrint('Persistent session store unavailable: $error');
    debugPrintStack(stackTrace: stack);
    store = InMemoryWorkflowStore();
  }

  // Development-only: seeds a Home state and picks a start route when the
  // matching dart-defines are set. Compiled out of production by the same
  // flag that removes the gallery and the capture tool.
  await HomeStatePreview.seed(config, store);

  runApp(
    ProviderScope(
      // The build's environment is an argument, not a global. Everything that
      // depends on it — including whether the development skip control may be
      // rendered at all — reads it from here, so a test can supply a
      // production configuration and get production behaviour.
      overrides: [
        environmentConfigProvider.overrideWithValue(config),
        workflowStoreProvider.overrideWithValue(store),
      ],
      child: DoseBandApp(
        config: config,
        initialLocation: HomeStatePreview.initialRoute(config),
      ),
    ),
  );
}

class DoseBandApp extends StatefulWidget {
  const DoseBandApp({required this.config, this.initialLocation, super.key});

  final EnvironmentConfig config;

  /// Overridden by tests to start on a specific screen, skipping the launch
  /// splash's timer and indeterminate animation. Null uses the real default.
  final String? initialLocation;

  @override
  State<DoseBandApp> createState() => _DoseBandAppState();
}

class _DoseBandAppState extends State<DoseBandApp> {
  late final GoRouter _router = widget.initialLocation == null
      ? buildRouter(widget.config)
      : buildRouter(widget.config, initialLocation: widget.initialLocation!);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'H2S DoseBand',
      debugShowCheckedModeBanner: false,
      // White-first: the light theme is the production theme, whatever the
      // phone's system setting (APP-PRODUCT-01 §50). The dark variant is not
      // offered; see docs/design/design-system-v2.md for why.
      theme: buildDoseBandTheme(brightness: Brightness.light),
      themeMode: ThemeMode.light,
      routerConfig: _router,
    );
  }
}
