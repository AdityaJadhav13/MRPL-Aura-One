import 'package:flutter/material.dart';

import '../design/product_colors.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../domain/connectivity.dart';
import '../domain/provenance.dart';

/// The colour family a status speaks in. There is no "positive" tone: nothing
/// in this product's status vocabulary is good news about the atmosphere, and
/// a green status would be read as exactly that (§10).
enum StatusTone {
  /// Plain ink. Complete, pending, not started — facts, not verdicts.
  neutral,

  /// Slate. Offline, not connected, unavailable: information about the
  /// system, never about the reading.
  info,

  /// Amber. Something needs a person: review required, retake.
  attention,

  /// Red. A genuine failure. Not a refusal to calculate.
  critical,

  /// Magenta. Simulated data. Nothing else.
  simulated,

  /// Cyan. The instrument is speaking: a measured state.
  instrument,
}

extension StatusToneColours on StatusTone {
  ({Color fg, Color container, Color border}) resolve(ProductColors p) =>
      switch (this) {
        StatusTone.neutral => (
          fg: p.textPrimary,
          container: p.surfaceSecondary,
          border: p.borderDefault,
        ),
        StatusTone.info => (
          fg: p.info,
          container: p.infoContainer,
          border: p.info.withValues(alpha: 0.4),
        ),
        StatusTone.attention => (
          fg: p.warning,
          container: p.warningContainer,
          border: p.warning.withValues(alpha: 0.4),
        ),
        StatusTone.critical => (
          fg: p.critical,
          container: p.criticalContainer,
          border: p.critical.withValues(alpha: 0.4),
        ),
        StatusTone.simulated => (
          fg: p.simulationAccent,
          container: p.simulationContainer,
          border: p.simulationAccent.withValues(alpha: 0.4),
        ),
        StatusTone.instrument => (
          fg: p.instrumentAccent,
          container: p.instrumentContainer,
          border: p.instrumentAccent.withValues(alpha: 0.4),
        ),
      };
}

/// The canonical status vocabulary (APP-PRODUCT-01 §20).
///
/// Every status carries a word and an icon, so none depends on colour. There
/// is deliberately no `safe`, `ok`, `clear` or `noDanger`: DoseBand cannot
/// certify an atmosphere, and a test asserts no such value appears.
///
/// These are *display* statuses. The domain lifecycles
/// (`DoseBandLifecycle`, `MonitoringSessionState`, `SyncState`) keep their own
/// qualified labels — "Monitoring complete" rather than "Complete" — and pass
/// them as the chip's label, so the same word never means two things.
enum ProductStatus {
  active('Active', Icons.sensors, StatusTone.info),
  complete('Complete', Icons.check_circle_outline, StatusTone.neutral),
  pending('Pending', Icons.schedule, StatusTone.neutral),
  reviewRequired(
    'Review required',
    Icons.rate_review_outlined,
    StatusTone.attention,
  ),
  offline('Offline', Icons.cloud_off_outlined, StatusTone.info),
  syncPending('Sync pending', Icons.cloud_upload_outlined, StatusTone.info),
  unavailable('Unavailable', Icons.block, StatusTone.info),
  notConnected('Not connected', Icons.link_off, StatusTone.info),
  simulated('Simulated', Icons.science_outlined, StatusTone.simulated),
  invalid('Invalid', Icons.do_not_disturb_on_outlined, StatusTone.attention),
  retake('Retake', Icons.replay, StatusTone.attention),
  noReading('No reading', Icons.remove_circle_outline, StatusTone.neutral),
  belowQuantification(
    'Below quantification',
    Icons.south,
    StatusTone.instrument,
  ),
  aboveRange('Above range', Icons.north, StatusTone.instrument),
  saturated('Saturated', Icons.vertical_align_top, StatusTone.instrument),
  unsupportedCalibration(
    'Unsupported calibration',
    Icons.tune,
    StatusTone.neutral,
  ),
  resultUnreliable(
    'Result unreliable',
    Icons.report_gmailerrorred_outlined,
    StatusTone.attention,
  );

  const ProductStatus(this.label, this.icon, this.tone);

  final String label;
  final IconData icon;
  final StatusTone tone;
}

/// A status: icon + word + tone, on a pale fill. Never colour alone.
class ProductStatusChip extends StatelessWidget {
  const ProductStatusChip(this.status, {this.label, super.key});

  final ProductStatus status;

  /// Overrides the generic word with a qualified one ("Monitoring complete").
  final String? label;

  @override
  Widget build(BuildContext context) {
    return ToneChip(
      label: label ?? status.label,
      icon: status.icon,
      tone: status.tone,
    );
  }
}

/// The one chip shape behind every status, provenance and sync marker.
class ToneChip extends StatelessWidget {
  const ToneChip({
    required this.label,
    required this.icon,
    required this.tone,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final IconData icon;
  final StatusTone tone;

  /// A fuller sentence for a screen reader, when the chip's word alone
  /// depends on having seen a legend.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final t = context.type;
    final colours = tone.resolve(p);

    return Semantics(
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.sm,
          vertical: Space.xs,
        ),
        decoration: BoxDecoration(
          color: colours.container,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: colours.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colours.fg),
            const SizedBox(width: Space.xs),
            // Wraps rather than truncates: a half-shown state is worse than a
            // two-line one.
            Flexible(
              child: Text(
                label,
                style: t.caption.copyWith(
                  color: colours.fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where a record came from, in the one vocabulary (§21).
///
/// Presentation data is normally declared once per screen rather than on every
/// row; this chip is for the places a single value's origin matters. A
/// simulated quantity must always carry one.
class ProvenanceChip extends StatelessWidget {
  const ProvenanceChip(this.provenance, {super.key});

  final RecordProvenance provenance;

  @override
  Widget build(BuildContext context) {
    final (icon, tone) = switch (provenance) {
      RecordProvenance.simulated => (
        Icons.science_outlined,
        StatusTone.simulated,
      ),
      RecordProvenance.realLocal => (
        Icons.phone_android_outlined,
        StatusTone.neutral,
      ),
      RecordProvenance.serverSynced => (
        Icons.cloud_done_outlined,
        StatusTone.neutral,
      ),
      RecordProvenance.presentationSeeded => (
        Icons.slideshow_outlined,
        StatusTone.neutral,
      ),
      RecordProvenance.manualEntry => (Icons.edit_outlined, StatusTone.neutral),
      RecordProvenance.organizationIntegration => (
        Icons.domain_verification_outlined,
        StatusTone.neutral,
      ),
      RecordProvenance.notConnected => (Icons.link_off, StatusTone.info),
      RecordProvenance.unavailable => (Icons.block, StatusTone.info),
    };
    return ToneChip(
      label: provenance.label,
      icon: icon,
      tone: tone,
      semanticLabel: '${provenance.label}. ${provenance.explanation}',
    );
  }
}

/// A record's position relative to the central server. Never a count.
class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip(this.state, {super.key});

  final SyncState state;

  @override
  Widget build(BuildContext context) {
    final (icon, tone) = switch (state) {
      SyncState.localOnly => (Icons.phone_android_outlined, StatusTone.neutral),
      SyncState.syncPending => (Icons.cloud_upload_outlined, StatusTone.info),
      SyncState.synced => (Icons.cloud_done_outlined, StatusTone.neutral),
      // A failed upload is attention, not critical, and never the same tone
      // as a measurement problem: the reading is unaffected (§140 Q7).
      SyncState.syncFailed => (Icons.sync_problem, StatusTone.attention),
      SyncState.notConnected => (Icons.link_off, StatusTone.info),
    };
    return ToneChip(
      label: state.label,
      icon: icon,
      tone: tone,
      semanticLabel: '${state.label}. ${state.explanation}',
    );
  }
}
