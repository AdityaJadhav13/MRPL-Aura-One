import 'package:flutter/material.dart';
import 'package:measurement/measurement.dart';

import '../../core/components/result_card.dart';
import '../../core/components/surfaces.dart';
import '../../core/design/theme.dart';

/// The result states worth inspecting, defined once.
///
/// Shared by the gallery screen and the golden tests, so what a reviewer looks
/// at and what CI guards are the same specimens rather than two drifting lists.
class ResultSpecimen {
  const ResultSpecimen({required this.name, required this.build});

  final String name;
  final Widget Function(BuildContext) build;
}

const double kLoq = 0.5;
const double kSaturation = 40;

final List<ResultSpecimen> resultSpecimens = [
  ResultSpecimen(
    name: 'Valid',
    build: (context) => const ResultCard(
      status: ResultStatus.valid,
      loq: kLoq,
      saturation: kSaturation,
      value: '3.2',
      uncertainty: '0.8',
      animate: false,
      traceability: {
        'Coverage': '7 h 52 min',
        'Badge': 'DB-4K7M2',
        'Lot': 'L26-0912-A',
        'Model': 'cal-1.2.0',
      },
    ),
  ),
  ResultSpecimen(
    name: 'Valid, with a caveat',
    build: (context) => ResultCard(
      status: ResultStatus.validWithWarning,
      loq: kLoq,
      saturation: kSaturation,
      value: '11.4',
      uncertainty: '2.9',
      animate: false,
      reason: ReasonPanel(
        whatHappened: 'The badge was partly covered during the shift.',
        whyItMatters:
            'A covered badge takes up less gas, so the true exposure may be '
            'higher than this reading.',
        whatToDo:
            'Keep the badge clear of your sleeve. Tell your safety '
            'officer about this shift.',
        colour: context.colours.statusWarning,
      ),
    ),
  ),
  ResultSpecimen(
    name: 'Above range',
    build: (context) => ResultCard(
      status: ResultStatus.aboveRange,
      loq: kLoq,
      saturation: kSaturation,
      prefix: '>',
      value: '40',
      animate: false,
      reason: ReasonPanel(
        whatHappened: 'The badge is saturated.',
        whyItMatters:
            'Your exposure was at least 40 ppm·h. The exact amount cannot be '
            'measured from this badge.',
        whatToDo: 'Report this to your safety officer now and fit a new badge.',
        colour: context.colours.statusCensored,
      ),
    ),
  ),
  ResultSpecimen(
    name: 'Below quantification limit',
    build: (context) => ResultCard(
      status: ResultStatus.belowQuantificationLimit,
      loq: kLoq,
      saturation: kSaturation,
      animate: false,
      reason: ReasonPanel(
        whatHappened: 'Any change is too small to measure.',
        whyItMatters:
            'Your exposure was below 0.5 ppm·h. This is not the same as zero — '
            'the badge cannot tell the difference down here.',
        whatToDo: 'No action needed. The shift is recorded.',
        colour: context.colours.statusCensored,
      ),
    ),
  ),
  ResultSpecimen(
    name: 'Refused — no reading',
    build: (context) => ResultCard(
      status: ResultStatus.referencePatchFailure,
      loq: kLoq,
      saturation: kSaturation,
      animate: false,
      reason: ReasonPanel(
        whatHappened: 'The reference patches could not be read.',
        whyItMatters:
            'Glare is covering the badge. Without the patches the colour '
            'cannot be corrected, so any number would be guesswork.',
        whatToDo: 'Tilt the badge away from the light and scan again.',
        colour: context.colours.statusRefused,
      ),
    ),
  ),
  ResultSpecimen(
    name: 'Refused — no calibration',
    build: (context) => ResultCard(
      status: ResultStatus.unsupportedCalibration,
      loq: kLoq,
      saturation: kSaturation,
      animate: false,
      reason: ReasonPanel(
        whatHappened: 'This phone has no calibration for lot L26-0912-A.',
        whyItMatters:
            'Without the calibration for this exact lot, the colour cannot be '
            'turned into an exposure figure.',
        whatToDo:
            'Connect to the network so the calibration can download, then scan '
            'again. The badge is still good.',
        colour: context.colours.statusRefused,
      ),
    ),
  ),
  ResultSpecimen(
    name: 'Long label stress test',
    build: (context) => ResultCard(
      status: ResultStatus.environmentOutsideValidatedRange,
      loq: kLoq,
      saturation: kSaturation,
      animate: false,
      reason: ReasonPanel(
        whatHappened:
            'Conditions during this shift were outside the range the badge has '
            'been tested in.',
        whyItMatters:
            'Temperature and humidity change how much gas the badge takes up. '
            'Outside the tested range the reading could be wrong in either '
            'direction, and we cannot say by how much.',
        whatToDo:
            'Record the shift as unmeasured and discuss placement with your '
            'safety officer before the next one.',
        colour: context.colours.statusRefused,
      ),
    ),
  ),
];
