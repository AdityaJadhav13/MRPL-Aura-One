import 'package:flutter/foundation.dart';

import '../../../core/domain/doseband.dart';

/// Where an HSE review of one measurement record stands (§41).
///
/// The fourth status axis (§48). It says what HSE has done with a record; it
/// never changes the record, the measurement result or the monitoring
/// session.
enum ReviewState {
  pending('Awaiting review'),
  inReview('In review'),
  infoRequired('Additional information required'),
  reviewed('Reviewed'),
  closed('Closed');

  const ReviewState(this.label);

  final String label;

  bool get isOpen =>
      this == pending || this == inReview || this == infoRequired;
}

/// Legal review transitions. As with the lifecycle policies, screens ask.
abstract final class ReviewPolicy {
  static const Map<ReviewState, Set<ReviewState>> _next = {
    ReviewState.pending: {ReviewState.inReview},
    ReviewState.inReview: {ReviewState.infoRequired, ReviewState.reviewed},
    ReviewState.infoRequired: {ReviewState.inReview},
    ReviewState.reviewed: {ReviewState.closed},
    ReviewState.closed: {},
  };

  static Set<ReviewState> nextFrom(ReviewState from) => _next[from]!;

  static LifecycleTransition<ReviewState> transition(
    ReviewState from,
    ReviewState to,
  ) => _next[from]!.contains(to)
      ? LifecycleTransition.accepted(to)
      : LifecycleTransition.refused(from, to);
}

/// What HSE decided to do about a reviewed record.
///
/// Operational follow-ups only. None of these is a medical conclusion: a
/// referral names the organisation's own occupational-health procedure, it
/// does not diagnose (§41).
enum ReviewDisposition {
  noFurtherAction('No further action'),
  repeatMonitoring('Repeat monitoring for this work'),
  investigateWorkArea('Investigate the work area'),
  referUnderSiteProcedure('Refer under the site occupational-health procedure');

  const ReviewDisposition(this.label);

  final String label;
}

/// HSE's review of one measurement record.
@immutable
final class HseReview {
  const HseReview({
    required this.reviewId,
    required this.measurementId,
    required this.state,
    required this.openedAt,
    required this.updatedAt,
    this.reviewerId,
    this.note,
    this.disposition,
  });

  final String reviewId;
  final String measurementId;
  final ReviewState state;
  final DateTime openedAt;
  final DateTime updatedAt;
  final String? reviewerId;

  /// Free text written by the reviewer. Operational, not clinical.
  final String? note;
  final ReviewDisposition? disposition;

  HseReview copyWith({
    ReviewState? state,
    DateTime? updatedAt,
    String? reviewerId,
    String? note,
    ReviewDisposition? disposition,
  }) => HseReview(
    reviewId: reviewId,
    measurementId: measurementId,
    state: state ?? this.state,
    openedAt: openedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    reviewerId: reviewerId ?? this.reviewerId,
    note: note ?? this.note,
    disposition: disposition ?? this.disposition,
  );
}
