import 'package:flutter/material.dart';
import 'package:measurement/measurement.dart';

import '../../../core/components/product_status.dart';
import '../../../core/domain/doseband.dart';
import '../../../core/domain/monitoring_session.dart';
import '../application/day_status.dart';
import '../domain/measurement_state.dart';
import '../domain/review.dart';

/// Status chips for the five separate axes (PRODUCT BUILD v1 §48). Each axis
/// has its own chip and its own words, so a row can show several side by
/// side without any of them reading as "complete". None uses brand green:
/// green is branding, never "safe" (§67, §143).

class DayStatusChip extends StatelessWidget {
  const DayStatusChip(this.status, {super.key});

  final WorkerDayStatus status;

  @override
  Widget build(BuildContext context) => ToneChip(
    label: status.label,
    icon: switch (status) {
      WorkerDayStatus.notStarted => Icons.schedule,
      WorkerDayStatus.claimed => Icons.qr_code_2,
      WorkerDayStatus.monitoring => Icons.sensors,
      WorkerDayStatus.finalReadDue => Icons.document_scanner_outlined,
      WorkerDayStatus.completed => Icons.task_alt,
      WorkerDayStatus.exception => Icons.report_outlined,
    },
    tone: switch (status) {
      WorkerDayStatus.notStarted ||
      WorkerDayStatus.completed => StatusTone.neutral,
      WorkerDayStatus.claimed || WorkerDayStatus.monitoring => StatusTone.info,
      WorkerDayStatus.finalReadDue => StatusTone.attention,
      WorkerDayStatus.exception => StatusTone.critical,
    },
  );
}

class MeasurementStateChip extends StatelessWidget {
  const MeasurementStateChip(this.result, {super.key});

  final MeasurementResult result;

  @override
  Widget build(BuildContext context) => ToneChip(
    label: MeasurementStateText.label(result.status),
    icon: switch (result) {
      Valid() => Icons.straighten,
      Censored() => Icons.unfold_more,
      Refused() => Icons.remove_circle_outline,
    },
    // Instrument tone for any technical outcome; a refusal is neutral, not an
    // alarm — "no reading" is not a finding about the worker.
    tone: result is Refused ? StatusTone.neutral : StatusTone.instrument,
  );
}

class ReviewStateChip extends StatelessWidget {
  const ReviewStateChip(this.state, {super.key});

  final ReviewState state;

  @override
  Widget build(BuildContext context) => ToneChip(
    label: state.label,
    icon: switch (state) {
      ReviewState.pending => Icons.hourglass_empty,
      ReviewState.inReview => Icons.rate_review_outlined,
      ReviewState.infoRequired => Icons.help_outline,
      ReviewState.reviewed => Icons.fact_check_outlined,
      ReviewState.closed => Icons.lock_outline,
    },
    tone: switch (state) {
      ReviewState.infoRequired => StatusTone.attention,
      ReviewState.pending || ReviewState.inReview => StatusTone.info,
      ReviewState.reviewed || ReviewState.closed => StatusTone.neutral,
    },
  );
}

class LifecycleChip extends StatelessWidget {
  const LifecycleChip(this.lifecycle, {super.key});

  final DoseBandLifecycle lifecycle;

  @override
  Widget build(BuildContext context) => ToneChip(
    label: lifecycle.label,
    icon: Icons.qr_code_2,
    tone: lifecycle.isExceptional
        ? StatusTone.attention
        : lifecycle == DoseBandLifecycle.monitoring
        ? StatusTone.info
        : StatusTone.neutral,
  );
}

class SessionStateChip extends StatelessWidget {
  const SessionStateChip(this.state, {super.key});

  final MonitoringSessionState state;

  @override
  Widget build(BuildContext context) => ToneChip(
    label: state.label,
    icon: Icons.timelapse,
    tone: switch (state) {
      MonitoringSessionState.active => StatusTone.info,
      MonitoringSessionState.readyForFinalRead => StatusTone.attention,
      MonitoringSessionState.interrupted ||
      MonitoringSessionState.finalReadMissing ||
      MonitoringSessionState.invalidRead => StatusTone.critical,
      _ => StatusTone.neutral,
    },
  );
}
