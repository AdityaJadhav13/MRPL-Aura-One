import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/buttons.dart';
import '../../../core/components/product_page.dart';
import '../../../core/components/product_states.dart';
import '../../../core/components/product_status.dart';
import '../../../core/components/workspace_components.dart';
import '../../../core/domain/doseband.dart';
import '../../../core/domain/doseband_registry.dart';
import '../../../core/util/format.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../auth/application/auth_controller.dart';
import '../../operations/application/local_doseband_registry.dart';
import '../../operations/application/operations_providers.dart';
import '../../operations/application/operations_repository.dart';
import '../../operations/domain/assignment.dart';
import '../../operations/domain/operations_snapshot.dart';
import '../../workflow/application/workflow_controller.dart';
import '../../workflow/domain/workflow_state.dart';
import '../application/doseband_providers.dart';
import '../domain/pre_use.dart';

/// The pre-use check and the assignment it leads to (PRODUCT BUILD v1 §10–§12).
///
/// 1. **Registry** — is this a known band, unused, in date, from a supported
///    lot? Decided by the store, not the photo.
/// 2. **Photograph** — can the band be read?
/// 3. **Verdict** — READY TO USE, REPLACE DOSEBAND, or CANNOT VERIFY — TRY
///    AGAIN. A bad photo is never "replace".
/// 4. **Assign** — the worker confirms; the store claims the band atomically
///    and monitoring starts.
class DoseBandCheckScreen extends ConsumerStatefulWidget {
  const DoseBandCheckScreen({required this.dosebandId, super.key});

  final String dosebandId;

  @override
  ConsumerState<DoseBandCheckScreen> createState() =>
      _DoseBandCheckScreenState();
}

class _DoseBandCheckScreenState extends ConsumerState<DoseBandCheckScreen> {
  OpticalResult? _optical;
  bool _busy = false;
  String? _claimProblem;
  final Set<PreUseOutcome> _recorded = {};

  Future<void> _photograph(DoseBand band) async {
    final result = await ref.read(opticalCheckProvider)(context, band);
    if (!mounted || result == null) return;
    setState(() => _optical = result);
  }

  /// Turned-away bands are recorded once, so a supervisor sees them (§37).
  void _recordOutcome(PreUseVerdict v) {
    if (v.outcome == PreUseOutcome.readyToUse) return;
    if (!_recorded.add(v.outcome)) return;
    final actor = ref.read(currentActorProvider);
    if (actor == null) return;
    // After the frame: this is reached from build, and the store must not
    // change while a widget is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(workerCommandsProvider)
          .recordPreUseOutcome(
            dosebandId: widget.dosebandId,
            outcome: v.outcome,
            reason:
                v.replaceReason?.name ??
                switch (_optical) {
                  OpticalNotReadable(:final reason) => reason,
                  OpticalCameraUnavailable(:final reason) => reason,
                  _ => null,
                },
          )
          .ignore();
    });
  }

  Future<void> _assign(DoseBand band) async {
    setState(() {
      _busy = true;
      _claimProblem = null;
    });
    try {
      final result = await ref
          .read(shiftSessionProvider.notifier)
          .claimAndStart(
            band: band,
            preUse: PreUseRecord(
              outcome: PreUseOutcome.readyToUse,
              checkedAt: ref.read(clockProvider)(),
              opticalCheck: _optical!.status,
            ),
          );
      if (!mounted) return;
      switch (result) {
        case ClaimAccepted():
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${band.dosebandId} assigned. Monitoring started.'),
            ),
          );
          context.go('/home');
        case ClaimConflict():
          setState(
            () => _claimProblem =
                'Someone else has just claimed this DoseBand. Use another.',
          );
        case ClaimWorkerHasActiveBand():
          setState(
            () => _claimProblem =
                'You already have a DoseBand whose period is not finished.',
          );
        case ClaimIneligible(:final lifecycle):
          setState(
            () => _claimProblem =
                'This DoseBand can no longer be used (${lifecycle.label}).',
          );
        case ClaimNotFound():
          setState(() => _claimProblem = 'This DoseBand is not in inventory.');
        case ClaimAuthorityUnavailable():
          setState(
            () => _claimProblem =
                'The DoseBand register could not be reached. Nothing was '
                'assigned.',
          );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(operationsProvider);
    final actor = ref.watch(currentActorProvider);
    final now = ref.watch(clockProvider)();
    final session = ref.watch(shiftSessionProvider).value ?? ShiftSession.none;
    final contextRecorded =
        session.context != null &&
        (session.stage == ShiftStage.contextSet ||
            session.stage == ShiftStage.noShift);

    return ProductPage(
      title: 'Check DoseBand',
      children: [
        OpsView<OperationsSnapshot>(
          value: snapshot,
          builder: (context, s) {
            if (actor == null) {
              return const StateView(
                kind: StateKind.permissionDenied,
                message: 'Sign in as a worker to check a DoseBand.',
              );
            }
            final band = s.bands[widget.dosebandId];
            final registry = DoseBandEligibility.assess(
              s,
              dosebandId: widget.dosebandId,
              workerId: actor.personId,
              now: now,
            );
            final eligible = registry is Eligible;
            final verdict = PreUseAssessment.verdict(
              registry,
              eligible ? _optical : null,
            );
            final decided = !eligible || _optical != null;
            if (decided) _recordOutcome(verdict);
            final lot = s.lot(band?.lotId);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionCard(
                  children: [
                    FactRow(
                      label: 'DoseBand',
                      value: widget.dosebandId,
                      mono: true,
                    ),
                    FactRow(
                      label: 'Lot',
                      value: band?.lotId ?? 'Unknown',
                      mono: true,
                    ),
                    FactRow(
                      label: 'Expiry',
                      value: lot?.expiresOn == null
                          ? 'Not recorded'
                          : Fmt.date(lot!.expiresOn!),
                    ),
                    FactRow(
                      label: 'Printed geometry',
                      value: band?.geometryVersion ?? 'Unknown',
                      mono: true,
                    ),
                  ],
                ),
                const SizedBox(height: Gaps.section),
                PageSection(
                  title: 'Checks',
                  children: [
                    _Check(
                      label: 'Known to the DoseBand register',
                      state: band == null ? _S.fail : _S.pass,
                    ),
                    _Check(
                      label: 'Unused, unassigned, in date and supported',
                      state: switch (registry) {
                        Eligible() => _S.pass,
                        _ when band == null => _S.skipped,
                        _ => _S.fail,
                      },
                    ),
                    _Check(
                      label: 'Readable in a photograph',
                      state: !eligible
                          ? _S.skipped
                          : switch (_optical) {
                              null => _S.pending,
                              OpticalReadable() => _S.pass,
                              _ => _S.retry,
                            },
                    ),
                    const _Check(
                      label: 'Sensor chemistry condition',
                      state: _S.notAssessed,
                    ),
                  ],
                ),
                if (decided) ...[
                  _VerdictBanner(verdict: verdict),
                  if (_optical case OpticalReadable(
                    :final correctionCaveat?,
                  )) ...[
                    const SizedBox(height: Space.sm),
                    Text(
                      correctionCaveat,
                      style: context.type.caption.copyWith(
                        color: context.product.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: Space.base),
                ],
                if (_claimProblem != null) ...[
                  StatusBanner(
                    tone: StatusTone.attention,
                    icon: Icons.block,
                    title: 'Not assigned',
                    message: _claimProblem!,
                  ),
                  const SizedBox(height: Space.base),
                ],
                ..._actions(
                  band: band,
                  eligible: eligible,
                  verdict: verdict,
                  contextRecorded: contextRecorded,
                ),
                const SizedBox(height: Space.base),
                const DataOriginNote(
                  'Checked against the DoseBand register on this device. A '
                  'central register is not connected, so another phone’s '
                  'claims are not visible here.',
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  List<Widget> _actions({
    required DoseBand? band,
    required bool eligible,
    required PreUseVerdict verdict,
    required bool contextRecorded,
  }) {
    if (!eligible || band == null) {
      return [
        DoseBandButton.primary(
          label: 'Scan another DoseBand',
          icon: Icons.qr_code_scanner,
          onPressed: () => context.pushReplacement('/doseband/scan'),
        ),
      ];
    }
    return switch (verdict.outcome) {
      PreUseOutcome.readyToUse => [
        if (!contextRecorded) ...[
          Text(
            'Record today’s work before the DoseBand is assigned: from the '
            'moment it is worn, its record needs to say where and on what.',
            style: context.type.body.copyWith(
              color: context.product.textPrimary,
            ),
          ),
          const SizedBox(height: Space.sm),
          DoseBandButton.primary(
            label: 'Record today’s work',
            icon: Icons.assignment_outlined,
            onPressed: () => context.push('/work-context'),
          ),
        ] else
          DoseBandButton.primary(
            label: 'Assign this DoseBand',
            icon: Icons.check,
            loading: _busy,
            onPressed: _busy ? null : () => _assign(band),
          ),
      ],
      _ => [
        DoseBandButton.primary(
          label: _optical == null ? 'Photograph the DoseBand' : 'Try again',
          icon: Icons.photo_camera_outlined,
          onPressed: () => _photograph(band),
        ),
        const SizedBox(height: Space.sm),
        DoseBandButton.secondary(
          label: 'Scan a different DoseBand',
          onPressed: () => context.pushReplacement('/doseband/scan'),
        ),
      ],
    };
  }
}

enum _S { pass, fail, retry, pending, skipped, notAssessed }

class _Check extends StatelessWidget {
  const _Check({required this.label, required this.state});

  final String label;
  final _S state;

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final t = context.type;
    final (IconData icon, Color colour, String word) = switch (state) {
      _S.pass => (Icons.check_circle_outline, p.instrumentAccent, 'Passed'),
      _S.fail => (Icons.cancel_outlined, p.critical, 'Failed'),
      _S.retry => (Icons.replay, p.warning, 'Try again'),
      _S.pending => (Icons.radio_button_unchecked, p.textSecondary, 'To do'),
      _S.skipped => (Icons.remove, p.textSecondary, 'Not reached'),
      _S.notAssessed => (Icons.help_outline, p.textSecondary, 'Not assessed'),
    };
    return Semantics(
      label: '$label: $word',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Row(
          children: [
            Icon(icon, color: colour, size: 22),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(label, style: t.body.copyWith(color: p.textPrimary)),
            ),
            Text(word, style: t.caption.copyWith(color: p.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _VerdictBanner extends StatelessWidget {
  const _VerdictBanner({required this.verdict});

  final PreUseVerdict verdict;

  @override
  Widget build(BuildContext context) => StatusBanner(
    // "Ready" is instrument-toned, not green: a usable band is not a safe
    // atmosphere (§67).
    tone: switch (verdict.outcome) {
      PreUseOutcome.readyToUse => StatusTone.instrument,
      PreUseOutcome.replace => StatusTone.critical,
      PreUseOutcome.cannotVerify => StatusTone.attention,
    },
    icon: switch (verdict.outcome) {
      PreUseOutcome.readyToUse => Icons.task_alt,
      PreUseOutcome.replace => Icons.block,
      PreUseOutcome.cannotVerify => Icons.replay,
    },
    title: verdict.title,
    message: verdict.message,
  );
}
