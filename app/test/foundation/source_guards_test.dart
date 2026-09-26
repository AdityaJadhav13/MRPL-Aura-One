import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source guards for the product foundation (APP-PRODUCT-01 §85, §86, §103,
/// §131).
///
/// Each guard is a **ratchet**: legacy occurrences are listed by file with
/// their count at the start of Phase 0, a count may fall but never rise, and
/// any file not listed must have none. So a later phase that migrates a file
/// lowers its entry, and nothing new can slip in quietly.
///
/// Remaining legacy occurrences are also recorded, with the phase that
/// removes them, in docs/engineering/ui-foundation-debt.md.

/// Non-comment lines of every Dart file under lib/.
Map<String, List<String>> _sources() {
  final out = <String, List<String>>{};
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    out[f.path.replaceAll(r'\', '/')] = f
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'))
        .toList();
  }
  return out;
}

int _count(List<String> lines, Pattern pattern) =>
    lines.fold(0, (n, l) => n + pattern.allMatches(l).length);

void _ratchet({
  required String name,
  required Pattern pattern,
  required Map<String, int> legacy,
  bool Function(String path)? exempt,
}) {
  final sources = _sources();
  final violations = <String>[];
  for (final e in sources.entries) {
    if (exempt?.call(e.key) ?? false) continue;
    final n = _count(e.value, pattern);
    final allowed = legacy[e.key] ?? 0;
    if (n > allowed) violations.add('${e.key}: $n (allowed $allowed)');
  }
  expect(violations, isEmpty, reason: 'new $name');

  // A migrated file should have its allowance lowered, so the ratchet keeps
  // biting. A stale allowance is reported, not failed on.
  for (final e in legacy.entries) {
    final lines = sources[e.key];
    if (lines == null) continue;
    final n = _count(lines, pattern);
    if (n < e.value) {
      // ignore: avoid_print
      print('[$name] ${e.key} is down to $n from ${e.value}: lower the entry.');
    }
  }
}

void main() {
  test('no new UI gradients (§8, §85)', () {
    _ratchet(
      name: 'gradient',
      pattern: RegExp(r'\b(Linear|Radial|Sweep)Gradient\b'),
      // All four are the authentication composition, rebuilt in P1. Home's
      // two gradients were removed in APP-PRODUCT-01.
      legacy: {
        'lib/features/auth/presentation/screens/sign_in_screen.dart': 1,
        'lib/features/auth/presentation/screens/splash_screen.dart': 2,
        'lib/features/auth/presentation/widgets/selection_cards.dart': 1,
        'lib/features/auth/presentation/widgets/auth_background.dart': 3,
      },
    );
  });

  test('no new literal colours outside the design tokens (§48, §86)', () {
    _ratchet(
      name: 'Color(0x…) literal',
      pattern: 'Color(0x',
      exempt: (p) => p.startsWith('lib/core/design/'),
      legacy: {
        // Research diagnostics draw overlay colours on a capture; they are
        // developer tooling, and recolouring them is not Phase 0 work.
        'lib/features/research/presentation/capture_diagnostics_screen.dart': 5,
        // The authentication composition, rebuilt in P1.
        'lib/features/auth/presentation/screens/splash_screen.dart': 13,
        'lib/features/auth/presentation/widgets/selection_cards.dart': 9,
        'lib/features/auth/presentation/widgets/auth_background.dart': 6,
        // Pre-work check, rebuilt in P2.
        'lib/features/workflow/presentation/prework_check_screen.dart': 1,
      },
    );
  });

  test('no new Material hue constants (§86)', () {
    _ratchet(
      name: 'Colors.<hue>',
      pattern: RegExp(
        r'Colors\.(red|green|orange|blue|yellow|amber|purple|pink|teal|cyan|'
        r'lime|indigo|brown|grey|blueGrey|deep\w+|light\w+|\w+Accent)\b',
      ),
      legacy: {
        // Camera overlays: the ROI guide on a live preview. Scientifically
        // neutral placement is P4's decision, not a Phase 0 recolour.
        'lib/features/research/presentation/capture_diagnostics_screen.dart': 2,
        'lib/features/capture/presentation/capture_screen.dart': 2,
      },
    );
  });

  test('no new uncontrolled wall-clock reads (§62, §103)', () {
    _ratchet(
      name: 'DateTime.now',
      pattern: 'DateTime.now',
      // The debt as found at the start of APP-PRODUCT-01. New code reads
      // `clockProvider` so time can be pinned in tests and goldens.
      legacy: {
        'lib/core/dev/home_state_preview.dart': 1,
        'lib/features/reporting/presentation/audit_package_screen.dart': 1,
        'lib/features/reporting/presentation/report_builder_screen.dart': 1,
        'lib/features/capture/data/capture_archive.dart': 1,
        'lib/features/capture/data/camera_port_impl.dart': 2,
        'lib/features/gallery/worker_preview_screen.dart': 3,
        'lib/features/scan/processing_screen.dart': 1,
        'lib/features/hse/presentation/hse_review_screens.dart': 2,
        'lib/features/hse/presentation/hse_screens.dart': 2,
        'lib/features/safety/presentation/safety_screens.dart': 1,
        // Includes the clock provider's own definition.
        'lib/features/workflow/application/workflow_controller.dart': 4,
        'lib/features/workflow/application/work_context_controller.dart': 1,
        'lib/features/workflow/data/simulation_catalog.dart': 1,
        'lib/features/workflow/presentation/prework_check_screen.dart': 1,
        'lib/features/workflow/presentation/active_monitoring_screen.dart': 1,
        'lib/features/workflow/presentation/context_detail_screens.dart': 1,
        'lib/features/workflow/presentation/end_monitoring_screen.dart': 1,
      },
    );
  });

  test('no route may demand ephemeral state (§33)', () {
    // `state.extra!` crashed twelve routes on deep links and cold restores.
    // Every extra-carrying route goes through the router's `_needs` guard.
    _ratchet(
      name: 'mandatory route extra',
      pattern: RegExp(r'\.extra\s*!|\.extra\s+as\s'),
      legacy: const {},
    );
  });

  test('research tooling is only registered behind the simulation flag', () {
    final router = File('lib/core/router/app_router.dart').readAsStringSync();
    final dev = router.indexOf("path: '/dev'");
    expect(dev, isNonNegative, reason: 'the /dev hub is registered');
    final guard = router.lastIndexOf('config.simulationAvailable', dev);
    expect(guard, isNonNegative);
    // The guard is the `if` immediately in front of the /dev route.
    expect(dev - guard, lessThan(120));
  });

  test('presentation people are only the approved team (§38)', () {
    const approved = {
      // A generic account label, not a person.
      'Demo User',
      'Aditya Jadhav',
      'Lavitra Satam',
      'Nikhil Sharma',
      'Aman Singh',
      'Samhita Hejmadi',
      'Yashvi Chotalia',
    };
    // Legacy seed data in two catalogs invented other names before this
    // rule existed. Listed here so the set cannot grow; replaced in the
    // phases that rebuild those catalogs (P7, P9).
    const legacy = {
      'Sunita Rao',
      'Rahul Shetty',
      'Priya Menon',
      'Meera Nair',
      'Joseph Fernandes',
      'Imran Qureshi',
    };
    final names = RegExp(r"'([A-Z][a-z]+ [A-Z][a-z]+)'");
    final nameFields = RegExp(
      r'(name|fullName|displayName|workerName|supervisor|officer|'
      r'reviewer|assignedTo|by)\s*:\s*'
      "'",
    );
    final unexpected = <String>{};
    for (final e in _sources().entries) {
      if (!e.key.contains('demo') && !e.key.contains('catalog')) continue;
      for (final line in e.value.where(nameFields.hasMatch)) {
        for (final m in names.allMatches(line)) {
          final n = m.group(1)!;
          if (!approved.contains(n) && !legacy.contains(n)) {
            unexpected.add('${e.key}: $n');
          }
        }
      }
    }
    expect(unexpected, isEmpty);
  });
}
