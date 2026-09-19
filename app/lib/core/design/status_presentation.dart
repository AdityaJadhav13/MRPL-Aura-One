import 'package:flutter/material.dart';
import 'package:measurement/measurement.dart';

import 'semantic_colors.dart';

/// How a [ResultStatus] is presented.
///
/// Status is carried by **icon + label + colour together**, never colour alone,
/// so it survives colour-vision deficiency, a sunlit screen, and a greyscale
/// screenshot pasted into an incident report.
///
/// Labels are sentence case. The interface is talking to a person at the end of
/// a shift, not stamping a form.
@immutable
class StatusPresentation {
  const StatusPresentation({
    required this.label,
    required this.icon,
    required this.colour,
  });

  final String label;
  final IconData icon;
  final Color colour;

  static StatusPresentation of(ResultStatus status, DoseBandColors c) {
    return switch (status) {
      ResultStatus.valid => StatusPresentation(
        label: 'Valid',
        icon: Icons.check_circle_outline,
        colour: c.statusValid,
      ),
      ResultStatus.validWithWarning => StatusPresentation(
        label: 'Valid, with a caveat',
        icon: Icons.error_outline,
        colour: c.statusWarning,
      ),
      ResultStatus.belowQuantificationLimit => StatusPresentation(
        label: 'Below measurable range',
        icon: Icons.south,
        colour: c.statusCensored,
      ),
      ResultStatus.aboveRange => StatusPresentation(
        label: 'Above measurable range',
        icon: Icons.north,
        colour: c.statusCensored,
      ),
      ResultStatus.saturated => StatusPresentation(
        label: 'Badge saturated',
        icon: Icons.north,
        colour: c.statusCensored,
      ),
      ResultStatus.poorImage => StatusPresentation(
        label: 'No reading',
        icon: Icons.block,
        colour: c.statusRefused,
      ),
      ResultStatus.badgeExpired => StatusPresentation(
        label: 'Badge expired',
        icon: Icons.block,
        colour: c.statusRefused,
      ),
      ResultStatus.badgeDamaged => StatusPresentation(
        label: 'Badge damaged',
        icon: Icons.block,
        colour: c.statusRefused,
      ),
      ResultStatus.badgeAlreadyUsed => StatusPresentation(
        label: 'Badge already read',
        icon: Icons.block,
        colour: c.statusRefused,
      ),
      ResultStatus.unsupportedBatch => StatusPresentation(
        label: 'Batch not supported',
        icon: Icons.block,
        colour: c.statusRefused,
      ),
      ResultStatus.unsupportedCalibration => StatusPresentation(
        label: 'No calibration for this badge',
        icon: Icons.block,
        colour: c.statusRefused,
      ),
      ResultStatus.referencePatchFailure => StatusPresentation(
        label: 'No reading',
        icon: Icons.block,
        colour: c.statusRefused,
      ),
      ResultStatus.blankFailure => StatusPresentation(
        label: 'No reading',
        icon: Icons.block,
        colour: c.statusRefused,
      ),
      ResultStatus.sensorBlankDisagreement => StatusPresentation(
        label: 'Result unreliable',
        icon: Icons.block,
        colour: c.statusRefused,
      ),
      ResultStatus.partialShift => StatusPresentation(
        label: 'Incomplete coverage',
        icon: Icons.timelapse,
        colour: c.statusRefused,
      ),
      ResultStatus.environmentOutsideValidatedRange => StatusPresentation(
        label: 'Conditions outside tested range',
        icon: Icons.block,
        colour: c.statusRefused,
      ),
      ResultStatus.contaminationSuspected => StatusPresentation(
        label: 'Contamination suspected',
        icon: Icons.block,
        colour: c.statusRefused,
      ),
      ResultStatus.resultUnreliable => StatusPresentation(
        label: 'Result unreliable',
        icon: Icons.block,
        colour: c.statusRefused,
      ),
    };
  }
}
