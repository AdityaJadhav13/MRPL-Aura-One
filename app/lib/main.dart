import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/design/theme.dart';
import 'core/env/environment.dart';
import 'core/router/app_router.dart';

/// Shared entry point. The per-flavour `main_*.dart` files each call this with
/// their own configuration, so there is exactly one startup path.
void bootstrap(EnvironmentConfig config) {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(DoseBandApp(config: config));
}

class DoseBandApp extends StatefulWidget {
  const DoseBandApp({required this.config, super.key});

  final EnvironmentConfig config;

  @override
  State<DoseBandApp> createState() => _DoseBandAppState();
}

class _DoseBandAppState extends State<DoseBandApp> {
  late final GoRouter _router = buildRouter(widget.config);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'H2S DoseBand',
      debugShowCheckedModeBanner: false,
      // Both themes are supplied and the system chooses. Industrial
      // environments need both: a sunlit yard and a dark tank interior.
      theme: buildDoseBandTheme(brightness: Brightness.light),
      darkTheme: buildDoseBandTheme(brightness: Brightness.dark),
      routerConfig: _router,
    );
  }
}
