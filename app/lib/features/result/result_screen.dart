import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:measurement/measurement.dart';

import '../../core/components/buttons.dart';
import '../../core/components/step_scaffold.dart';
import '../../core/components/surfaces.dart';
import '../../core/components/result_card.dart';
import '../../core/design/status_presentation.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/util/format.dart';
import '../history/domain/measurement_record.dart';
import 'result_presentation.dart';

/// The result screen.
///
/// The payoff of the whole journey, rendered through the shared `ResultCard` so
/// every state — valid, censored, refused — uses the same instrument face. A
/// refusal shows the empty readout slot and its what/why/what-to-do; it never
/// shows a zero.
class ResultScreen extends StatefulWidget {
  const ResultScreen({required this.record, super.key});

  final MeasurementRecord record;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  void initState() {
    super.initState();
    // Valid and refused feel different — a worker can tell them apart without
    // looking (design system: haptics).
    final status = widget.record.result.status;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (status.carriesDose) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.vibrate();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final record = widget.record;
    final result = record.result;
    final view = ResultView.of(result);
    final status = result.status;
    final presentation = StatusPresentation.of(status, c);

    final reasonPanel = view.copy == null
        ? null
        : ReasonPanel(
            whatHappened: view.copy!.whatHappened,
            whyItMatters: view.copy!.whyItMatters,
            whatToDo: view.copy!.whatToDo,
            colour: presentation.colour,
          );

    // A real scan of a physical badge is not simulated, and must not say so.
    // The marker used to be inherited from the scaffold's default, which put
    // "Simulated — not a real H₂S measurement" over a real photograph's
    // honest no-calibration refusal.
    final simulated = record.domain == DataDomain.simulated;

    return StepScaffold(
      register: StepRegister.instrument,
      title: 'Exposure result',
      simulated: simulated,
      // "Scan again" only for a simulated specimen. A physical scan has
      // completed its monitored period, and reopening the camera on it threw
      // when the second result tried to complete a closed session. A re-read
      // would need a superseding record, never a rewrite of this one (§78) —
      // and no rescan turns "no calibration exists" into a value.
      primaryAction: status.isRefusal && simulated
          ? DoseBandButton.primary(
              label: 'Scan again',
              icon: Icons.refresh,
              onPressed: () => context.pushReplacement('/read'),
            )
          : DoseBandButton.primary(
              label: 'Done',
              icon: Icons.check,
              onPressed: () => context.go('/home'),
            ),
      secondaryAction: DoseBandButton.secondary(
        label: 'View measurement details',
        onPressed: () => context.push('/measurement', extra: record),
      ),
      children: [
        ResultCard(
          status: status,
          loq: view.loq,
          saturation: view.saturation,
          value: view.value,
          prefix: view.prefix,
          uncertainty: view.uncertainty,
          reason: reasonPanel,
          traceability: {
            'Coverage': Fmt.duration(record.coverage),
            'Badge': record.badge.badgeId,
            if (result case Valid(:final provenance))
              'Model': provenance.calibrationModelId ?? '—',
          },
        ),
        if (!simulated) ...[
          const SizedBox(height: Space.base),
          _RealScanSummary(record: record),
        ],
        if (status.carriesDose) ...[
          const SizedBox(height: Space.base),
          _ValidNote(),
          const SizedBox(height: Space.sm),
          const _NoProductionCalibrationNote(),
        ],
      ],
    );
  }
}

/// For a real photograph: the four questions a worker has after a scan
/// (PRODUCT BUILD v1 §142) — was the photo usable, did a calibration apply,
/// what state is the record in, and what now. No matrices, no ΔE arrays.
class _RealScanSummary extends StatelessWidget {
  const _RealScanSummary({required this.record});

  final MeasurementRecord record;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final t = context.type;
    final status = record.result.status;
    final photoUsable = !const {
      ResultStatus.poorImage,
      ResultStatus.referencePatchFailure,
    }.contains(status);
    final calibrated = record.result is Valid || record.result is Censored;
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.caption.copyWith(color: c.textSecondary)),
          Text(value, style: t.body.copyWith(color: c.textPrimary)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row(
          'Photograph',
          photoUsable
              ? 'Captured and processed on this phone.'
              : 'Captured, but it could not be measured: '
                    '${status == ResultStatus.referencePatchFailure ? 'the reference colours did not verify.' : 'the image quality was not sufficient.'}',
        ),
        row(
          'Calibration',
          calibrated
              ? 'Applied.'
              : 'Not available. Optical measurement completed; quantitative '
                    'H₂S calibration is not available for this configuration.',
        ),
        row('Record', 'Saved on this phone. Not sent anywhere.'),
        row(
          'Next',
          'Remove the DoseBand and dispose of it following your site '
              'procedure. It is not reused.',
        ),
      ],
    );
  }
}

class _ValidNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Text(
      'Valid means the measurement passed its validity checks. It does not mean '
      'the exposure was safe — that is for your safety officer to interpret.',
      style: context.type.caption.copyWith(color: c.textSecondary),
    );
  }
}

/// The boundary under every number this product currently shows.
///
/// A dose on this screen came from a simulation specimen's *declared* outcome
/// played through the real result state machine — it was not computed from an
/// image, because no calibration model exists to compute it with. The magenta
/// simulation marker at the top of the screen says the data is simulated; this
/// says why a real badge would not produce a number either.
///
/// Both are needed. A worker who sees the marker may still assume the maths
/// behind it is finished.
class _NoProductionCalibrationNote extends StatelessWidget {
  const _NoProductionCalibrationNote();

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final t = context.type;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: c.surfaceSunken,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No production H\u2082S calibration available',
            style: t.label.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: Space.xs),
          Text(
            'This figure comes from a simulated specimen, not from a '
            'measurement. No validated calibration model exists, so a real '
            'badge read through this application would report that the '
            'badge was read and that the quantity is unavailable.',
            style: t.caption.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
