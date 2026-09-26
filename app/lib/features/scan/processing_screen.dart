import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:measurement/measurement.dart' show DataDomain;

import '../../core/components/markers.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/util/async_value_x.dart';
import '../history/application/history_controller.dart';
import '../history/domain/measurement_record.dart';
import '../workflow/application/workflow_controller.dart';
import '../workflow/domain/workflow_state.dart';

/// Processing.
///
/// Represents the deterministic measurement pipeline stage by stage, rather than
/// an unexplained spinner (directive §14). In simulation the stages are played
/// out on a timer and the SIMULATED marker stays up; the real pipeline in
/// Phase 3+ drives the same stage list from actual work.
class ProcessingScreen extends ConsumerStatefulWidget {
  const ProcessingScreen({super.key});

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen> {
  static const _stages = <String>[
    'Badge identified',
    'Geometry corrected',
    'Reference patches detected',
    'Colour normalization checked',
    'Sensing region measured',
    // Not "Calibration applied": several specimens play out a no-calibration
    // outcome, and for them that stage never happened. §75.
    'Result state determined',
    'Validity checks completed',
  ];

  int _done = 0;
  Timer? _timer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 320), (t) {
      if (!mounted) return;
      if (_done < _stages.length) {
        setState(() => _done++);
      } else {
        t.cancel();
        _finish();
      }
    });
  }

  Future<void> _finish() async {
    if (_navigated) return;
    _navigated = true;
    final session =
        ref.read(shiftSessionProvider).dataOrNull ?? ShiftSession.none;
    final result = await ref.read(shiftSessionProvider.notifier).completeScan();
    final badge = session.badge;
    final ctx = session.context;
    if (badge == null || ctx == null) {
      if (mounted) context.go('/home');
      return;
    }
    final now = DateTime.now();
    final record = MeasurementRecord(
      id: 'M-${now.microsecondsSinceEpoch}',
      result: result,
      badge: badge,
      context: ctx,
      startedAt: session.startedAt ?? now,
      endedAt: session.endedAt ?? now,
      scannedAt: now,
      // Stated, not defaulted: this path replays a simulated specimen's
      // declared outcome. A physical badge never reaches this screen.
      domain: DataDomain.simulated,
    );
    ref.read(historyProvider.notifier).add(record);
    if (mounted) context.pushReplacement('/result', extra: record);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final t = context.type;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Processing'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          const SimulationMarker(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(Space.lg),
              children: [
                Text(
                  'Reading the badge',
                  style: t.heading.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: Space.lg),
                for (var i = 0; i < _stages.length; i++)
                  _StageRow(
                    label: _stages[i],
                    done: i < _done,
                    active: i == _done,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.label,
    required this.done,
    required this.active,
  });

  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final t = context.type;
    final Widget leading;
    if (done) {
      leading = Icon(Icons.check_circle, size: 20, color: c.statusValid);
    } else if (active) {
      leading = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: c.measurementAccent,
        ),
      );
    } else {
      leading = Icon(
        Icons.radio_button_unchecked,
        size: 20,
        color: c.textDisabled,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: Row(
        children: [
          leading,
          const SizedBox(width: Space.md),
          Text(
            label,
            style: t.body.copyWith(
              color: done || active ? c.textPrimary : c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
