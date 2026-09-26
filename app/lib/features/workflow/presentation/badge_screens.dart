import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/buttons.dart';
import '../../../core/components/corporate.dart';
import '../../../core/components/step_scaffold.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/util/async_value_x.dart';
import '../../../core/util/format.dart';
import '../application/workflow_controller.dart';
import '../domain/badge_specimen.dart';
import '../domain/workflow_state.dart';

/// Gate-pass-style QR assignment.
///
/// ## Why there is no camera here yet
///
/// Reading a badge's QR code means decoding a real code and resolving it to a
/// real badge record. Neither exists: no badge has been manufactured, so there
/// is no code to print on one and no registry to resolve it against.
///
/// A viewfinder that "recognises" whatever you point it at would be the single
/// most convincing fake in this product — a worker would watch it find a badge
/// and reasonably conclude the whole measurement chain works. So the frame is
/// drawn, the states are designed, and the camera is honestly absent.
class ScanBadgeQrScreen extends StatelessWidget {
  const ScanBadgeQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final corporate = context.corporate;
    final t = context.type;

    return StepScaffold(
      title: 'Scan badge QR',
      simulated: false,
      // Instrument register: the viewfinder is a neutral surface, and a
      // saturated corporate field around it would be the start of the same
      // mistake the measurement screens avoid.
      register: StepRegister.instrument,
      primaryAction: DoseBandButton.primary(
        label: 'Choose a badge manually',
        icon: Icons.list_alt,
        onPressed: () => context.pushReplacement('/assign'),
      ),
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: c.surfaceViewfinder,
              borderRadius: BorderRadius.circular(Radii.control),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size.infinite,
                  painter: _QrFramePainter(colour: Neutral.l58),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.no_photography_outlined,
                        size: 42,
                        color: Neutral.l74,
                      ),
                      const SizedBox(height: Space.md),
                      Text(
                        'Camera not available',
                        textAlign: TextAlign.center,
                        style: t.bodyStrong.copyWith(color: Neutral.l86),
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        'No DoseBand has been manufactured, so there is no '
                        'code to read and no registry to resolve it against.',
                        textAlign: TextAlign.center,
                        style: t.caption.copyWith(color: Neutral.l74),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        Text(
          'States this screen will handle',
          style: t.label.copyWith(color: corporate.textPrimary),
        ),
        const SizedBox(height: Space.sm),
        InfoCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: const [
              _PlannedState(
                icon: Icons.photo_camera_outlined,
                label: 'Camera ready',
              ),
              _PlannedState(
                icon: Icons.lock_outline,
                label: 'Camera permission required',
              ),
              _PlannedState(
                icon: Icons.qr_code_2,
                label: 'Code found — resolving badge',
              ),
              _PlannedState(icon: Icons.help_outline, label: 'Unknown badge'),
              _PlannedState(
                icon: Icons.person_off_outlined,
                label: 'Already assigned to another worker',
              ),
              _PlannedState(icon: Icons.block, label: 'Badge not usable'),
              _PlannedState(
                icon: Icons.keyboard_outlined,
                label: 'Manual entry',
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.base),
        InfoCard(
          child: Text(
            'Until a badge exists, assignment uses the simulated badge list. '
            'Those specimens are marked as simulated everywhere they appear '
            'and can never become a production record.',
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _PlannedState extends StatelessWidget {
  const _PlannedState({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.sm,
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: corporate.textSecondary),
          const SizedBox(width: Space.md),
          Expanded(
            child: Text(
              label,
              style: t.body.copyWith(color: corporate.textSecondary),
            ),
          ),
          Text(
            'Planned',
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// The corner brackets of a QR viewfinder.
class _QrFramePainter extends CustomPainter {
  const _QrFramePainter({required this.colour});

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final inset = size.width * 0.22;
    final arm = size.width * 0.09;
    final rect = Rect.fromLTRB(
      inset,
      inset,
      size.width - inset,
      size.height - inset,
    );

    for (final corner in <(Offset, double, double)>[
      (rect.topLeft, 1, 1),
      (rect.topRight, -1, 1),
      (rect.bottomLeft, 1, -1),
      (rect.bottomRight, -1, -1),
    ]) {
      final (origin, dx, dy) = corner;
      canvas.drawLine(origin, origin.translate(arm * dx, 0), paint);
      canvas.drawLine(origin, origin.translate(0, arm * dy), paint);
    }
  }

  @override
  bool shouldRepaint(_QrFramePainter oldDelegate) =>
      oldDelegate.colour != colour;
}

/// A badge's lifecycle.
///
/// ## What the states actually mean here
///
/// Only the stages this application observed are real: assignment, activation,
/// monitoring and reading, which come from the workflow. Everything before
/// assignment — manufacture, batch release, inventory, issue — describes a
/// supply chain that **does not exist**. No DoseBand has been made.
///
/// Those stages are therefore drawn as unavailable rather than as completed
/// steps with invented dates. A fabricated manufacturing record is worse than
/// a fabricated measurement: nobody interrogates a date on a traceability
/// timeline.
class BadgeTraceabilityScreen extends ConsumerWidget {
  const BadgeTraceabilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session =
        ref.watch(shiftSessionProvider).dataOrNull ?? ShiftSession.none;
    final badge = session.badge;

    return StepScaffold(
      title: 'Badge traceability',
      simulated: false,
      children: badge == null
          ? const [
              InfoCard(
                child: Text(
                  'No DoseBand is assigned to this monitored period.',
                ),
              ),
            ]
          : [
              InfoCard(
                child: Column(
                  children: [
                    RecordRow(label: 'Badge', value: badge.badgeId, mono: true),
                    RecordRow(label: 'Lot', value: badge.lot, mono: true),
                    RecordRow(label: 'Formulation', value: badge.formulation),
                    RecordRow(
                      label: 'Geometry',
                      value: badge.geometryVersion,
                      mono: true,
                    ),
                  ],
                ),
              ),
              const SectionHeader(title: 'Lifecycle'),
              _Lifecycle(badge: badge, session: session),
              const SizedBox(height: Space.base),
              InfoCard(
                child: Text(
                  'Stages before assignment describe a supply chain that does '
                  'not exist yet — no DoseBand has been manufactured. They are '
                  'shown unavailable rather than filled with invented dates.',
                  style: context.type.caption.copyWith(
                    color: context.corporate.textSecondary,
                  ),
                ),
              ),
            ],
    );
  }
}

enum _StageState { unavailable, done, current, upcoming }

class _Lifecycle extends StatelessWidget {
  const _Lifecycle({required this.badge, required this.session});

  final BadgeSpecimen badge;
  final ShiftSession session;

  @override
  Widget build(BuildContext context) {
    final stage = session.stage;

    List<(String, _StageState, String?)> stages() {
      _StageState after(ShiftStage s) => stage.index > s.index
          ? _StageState.done
          : stage.index == s.index
          ? _StageState.current
          : _StageState.upcoming;

      return [
        // No evidence exists for any of these.
        ('Manufactured', _StageState.unavailable, null),
        ('Batch released', _StageState.unavailable, null),
        ('Inventory', _StageState.unavailable, null),
        ('Issued', _StageState.unavailable, null),
        // From here the workflow is the evidence.
        (
          'Assigned',
          stage.index >= ShiftStage.badgeAssigned.index
              ? _StageState.done
              : _StageState.upcoming,
          badge.badgeId,
        ),
        (
          'Activated',
          stage.index >= ShiftStage.monitoring.index
              ? _StageState.done
              : _StageState.upcoming,
          session.startedAt == null ? null : Fmt.stamp(session.startedAt!),
        ),
        ('Monitoring', after(ShiftStage.monitoring), null),
        (
          'Read',
          stage == ShiftStage.complete
              ? _StageState.done
              : _StageState.upcoming,
          session.endedAt == null ? null : Fmt.stamp(session.endedAt!),
        ),
        ('Reviewed', _StageState.unavailable, null),
        ('Archived or disposed', _StageState.unavailable, null),
      ];
    }

    final rows = stages();

    return InfoCard(
      padding: const EdgeInsets.all(Space.md),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            _StageRow(
              label: rows[i].$1,
              state: rows[i].$2,
              detail: rows[i].$3,
              isLast: i == rows.length - 1,
            ),
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.label,
    required this.state,
    required this.detail,
    required this.isLast,
  });

  final String label;
  final _StageState state;
  final String? detail;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    final (icon, colour, note) = switch (state) {
      _StageState.done => (Icons.check_circle, corporate.primary, detail),
      _StageState.current => (
        Icons.radio_button_checked,
        corporate.accent,
        detail ?? 'In progress',
      ),
      _StageState.upcoming => (
        Icons.radio_button_unchecked,
        corporate.textSecondary,
        null,
      ),
      // Not "pending": nothing is pending, because no such record exists.
      _StageState.unavailable => (
        Icons.remove_circle_outline,
        corporate.textSecondary,
        'No record exists',
      ),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(icon, size: 17, color: colour),
              if (!isLast)
                Expanded(child: Container(width: 1, color: corporate.border)),
            ],
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : Space.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: t.body.copyWith(
                      color: state == _StageState.unavailable
                          ? corporate.textSecondary
                          : corporate.textPrimary,
                    ),
                  ),
                  if (note != null)
                    Text(
                      note,
                      style: t.caption.copyWith(color: corporate.textSecondary),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
