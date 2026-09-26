import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Goldens must not depend on the day they were generated.
///
/// Home renders today's date, so a widget that reads `DateTime.now()` bakes the
/// generation day into every golden containing it. Those goldens then fail at
/// the next midnight — on a calendar boundary rather than on a regression.
///
/// That failure mode is worse than it looks. A suite that goes red on a
/// schedule teaches whoever sees it to run `--update-goldens` without reading
/// the diff, and a golden nobody reads has stopped being the visual review
/// artefact ADR-0010 says it is. It cost exactly that once: eight Home goldens
/// went red overnight over a single digit.
///
/// Home was fixed by injecting `clockProvider`. The sites below were **not**
/// audited — doing so would have meant refactoring twenty files across a frozen
/// UI, which is not what the M0C phase is for. They are listed so that:
///
///   * the debt is visible rather than forgotten, and
///   * the number cannot grow quietly. New code uses `clockProvider`.
///
/// Removing an entry from this list is the right way to pay it down.
const knownWallClockReads = <String>{
  'lib/core/dev/home_state_preview.dart',
  'lib/features/capture/data/capture_archive.dart',
  'lib/features/capture/data/camera_port_impl.dart',
  'lib/features/gallery/worker_preview_screen.dart',
  'lib/features/hse/presentation/hse_review_screens.dart',
  'lib/features/hse/presentation/hse_screens.dart',
  'lib/features/reporting/presentation/audit_package_screen.dart',
  'lib/features/reporting/presentation/report_builder_screen.dart',
  'lib/features/safety/presentation/safety_screens.dart',
  'lib/features/scan/processing_screen.dart',
  'lib/features/workflow/application/work_context_controller.dart',
  'lib/features/workflow/data/simulation_catalog.dart',
  'lib/features/workflow/presentation/active_monitoring_screen.dart',
  'lib/features/workflow/presentation/context_detail_screens.dart',
  'lib/features/workflow/presentation/end_monitoring_screen.dart',
  'lib/features/workflow/presentation/prework_check_screen.dart',
};

void main() {
  test('no new widget reads the wall clock directly', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      // The provider's whole job is to be the one place that calls it.
      if (entity.path.endsWith('workflow_controller.dart')) continue;
      if (knownWallClockReads.contains(entity.path)) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        if (!line.contains('DateTime.now()')) continue;
        offenders.add('${entity.path}:${i + 1}  ${line.trim()}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These read the wall clock directly, which makes any golden '
          'containing them fail on a calendar boundary. Use clockProvider:\n'
          '${offenders.join('\n')}',
    );
  });

  test('the known-offender list has no stale entries', () {
    // A list that keeps naming files which no longer offend is a list nobody
    // trusts, and it would let a genuinely new offender hide behind a name
    // that happens to still be on it.
    final stale = <String>[];

    for (final path in knownWallClockReads) {
      final file = File(path);
      if (!file.existsSync()) {
        stale.add('$path (file no longer exists)');
        continue;
      }
      final reads = file
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .any((l) => l.contains('DateTime.now()'));
      if (!reads) stale.add('$path (no longer reads the clock — remove it)');
    }

    expect(stale, isEmpty, reason: stale.join('\n'));
  });
}
