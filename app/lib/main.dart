import 'package:flutter/material.dart';
import 'package:h2s_doseband/core/env/environment.dart';

/// Shared entry point. The per-flavour `main_*.dart` files each call this with
/// their own configuration, so there is exactly one startup path.
void bootstrap(EnvironmentConfig config) {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(DoseBandApp(config: config));
}

/// Phase 0 placeholder.
///
/// The design system, navigation shell and worker workflow arrive in Phases 1
/// and 2. This screen exists so that the flavour wiring is verifiable today
/// rather than assumed.
class DoseBandApp extends StatelessWidget {
  const DoseBandApp({required this.config, super.key});

  final EnvironmentConfig config;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'H2S DoseBand',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.light),
      darkTheme: ThemeData(brightness: Brightness.dark),
      home: PhaseZeroScreen(config: config),
    );
  }
}

class PhaseZeroScreen extends StatelessWidget {
  const PhaseZeroScreen({required this.config, super.key});

  final EnvironmentConfig config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('H₂S DoseBand', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Phase 0 — architecture only. No measurement capability yet.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              _Row(label: 'Environment', value: config.environment.name),
              _Row(
                label: 'Backend',
                value: config.isConfigured ? 'configured' : 'not configured',
              ),
              _Row(
                label: 'Simulation',
                value: config.simulationAvailable
                    ? 'available'
                    : 'compiled out',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: theme.textTheme.labelLarge),
          ),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
