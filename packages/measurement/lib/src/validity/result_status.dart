/// Every outcome the measurement pipeline may report.
///
/// Directive section 5. The software must not always produce a number.
enum ResultStatus {
  valid(_Kind.valued),
  validWithWarning(_Kind.valued),

  // Censored: the measurement succeeded, but the true value lies outside the
  // interval the calibration can quantify. These are neither errors nor
  // numbers, and collapsing them into either would misreport.
  belowQuantificationLimit(_Kind.censored),
  aboveRange(_Kind.censored),
  saturated(_Kind.censored),

  // Refusals.
  poorImage(_Kind.refused),
  badgeExpired(_Kind.refused),
  badgeDamaged(_Kind.refused),
  badgeAlreadyUsed(_Kind.refused),
  unsupportedBatch(_Kind.refused),
  unsupportedCalibration(_Kind.refused),
  referencePatchFailure(_Kind.refused),
  blankFailure(_Kind.refused),
  sensorBlankDisagreement(_Kind.refused),
  partialShift(_Kind.refused),
  environmentOutsideValidatedRange(_Kind.refused),
  contaminationSuspected(_Kind.refused),
  resultUnreliable(_Kind.refused);

  const ResultStatus(this._kind);

  final _Kind _kind;

  /// Whether this status is permitted to carry a dose. Only two are.
  bool get carriesDose => _kind == _Kind.valued;

  bool get isCensored => _kind == _Kind.censored;

  bool get isRefusal => _kind == _Kind.refused;
}

enum _Kind { valued, censored, refused }
