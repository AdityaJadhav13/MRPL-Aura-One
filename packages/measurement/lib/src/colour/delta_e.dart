import 'dart:math' as math;

import 'colour_types.dart';

double _deg2rad(double d) => d * math.pi / 180.0;

/// CIE76 colour difference. Directive s19.
///
/// Plain Euclidean distance in CIELAB. Cheap, and perceptually uneven — its
/// value here is as a comparator, not as a presumed best metric.
double deltaE76(Lab a, Lab b) {
  final dl = a.lStar - b.lStar;
  final da = a.aStar - b.aStar;
  final db = a.bStar - b.bStar;
  return math.sqrt(dl * dl + da * da + db * db);
}

/// CIEDE2000 colour difference. Directive s19.
///
/// Implemented from the CIE definition as set out by Sharma, Wu and Dalal
/// (2005), including the hue-arithmetic edge cases that make this formula easy
/// to get subtly and undetectably wrong. It is verified against that paper's
/// published 34-pair test set in
/// `test/colour/delta_e_test.dart`; an implementation of this function that has
/// not been checked against those vectors should not be trusted.
///
/// [kL], [kC] and [kH] are the parametric weighting factors; all default to 1,
/// which is the reference-condition value.
double deltaE2000(
  Lab lab1,
  Lab lab2, {
  double kL = 1.0,
  double kC = 1.0,
  double kH = 1.0,
}) {
  final l1 = lab1.lStar, a1 = lab1.aStar, b1 = lab1.bStar;
  final l2 = lab2.lStar, a2 = lab2.aStar, b2 = lab2.bStar;

  final c1ab = math.sqrt(a1 * a1 + b1 * b1);
  final c2ab = math.sqrt(a2 * a2 + b2 * b2);
  final cBarAb = (c1ab + c2ab) / 2.0;

  final cBarAb7 = math.pow(cBarAb, 7).toDouble();
  final g = 0.5 * (1.0 - math.sqrt(cBarAb7 / (cBarAb7 + 6103515625.0)));

  final a1p = (1.0 + g) * a1;
  final a2p = (1.0 + g) * a2;

  final c1p = math.sqrt(a1p * a1p + b1 * b1);
  final c2p = math.sqrt(a2p * a2p + b2 * b2);

  // Hue is undefined for a neutral sample. The CIE definition sets it to zero
  // rather than leaving atan2(0, 0) to the platform.
  double hue(double bb, double ap) {
    if (bb == 0.0 && ap == 0.0) return 0.0;
    final h = math.atan2(bb, ap) * 180.0 / math.pi;
    return h < 0 ? h + 360.0 : h;
  }

  final h1p = hue(b1, a1p);
  final h2p = hue(b2, a2p);

  final dLp = l2 - l1;
  final dCp = c2p - c1p;

  final chromaProduct = c1p * c2p;
  double dhp;
  if (chromaProduct == 0.0) {
    dhp = 0.0;
  } else {
    final diff = h2p - h1p;
    if (diff.abs() <= 180.0) {
      dhp = diff;
    } else if (diff > 180.0) {
      dhp = diff - 360.0;
    } else {
      dhp = diff + 360.0;
    }
  }
  final dHp = 2.0 * math.sqrt(chromaProduct) * math.sin(_deg2rad(dhp / 2.0));

  final lBarP = (l1 + l2) / 2.0;
  final cBarP = (c1p + c2p) / 2.0;

  double hBarP;
  if (chromaProduct == 0.0) {
    hBarP = h1p + h2p;
  } else {
    final sum = h1p + h2p;
    if ((h1p - h2p).abs() <= 180.0) {
      hBarP = sum / 2.0;
    } else if (sum < 360.0) {
      hBarP = (sum + 360.0) / 2.0;
    } else {
      hBarP = (sum - 360.0) / 2.0;
    }
  }

  final t =
      1.0 -
      0.17 * math.cos(_deg2rad(hBarP - 30.0)) +
      0.24 * math.cos(_deg2rad(2.0 * hBarP)) +
      0.32 * math.cos(_deg2rad(3.0 * hBarP + 6.0)) -
      0.20 * math.cos(_deg2rad(4.0 * hBarP - 63.0));

  final dTheta =
      30.0 * math.exp(-math.pow((hBarP - 275.0) / 25.0, 2).toDouble());
  final cBarP7 = math.pow(cBarP, 7).toDouble();
  final rC = 2.0 * math.sqrt(cBarP7 / (cBarP7 + 6103515625.0));
  final rT = -math.sin(_deg2rad(2.0 * dTheta)) * rC;

  final lBarMinus50Sq = (lBarP - 50.0) * (lBarP - 50.0);
  final sL = 1.0 + (0.015 * lBarMinus50Sq) / math.sqrt(20.0 + lBarMinus50Sq);
  final sC = 1.0 + 0.045 * cBarP;
  final sH = 1.0 + 0.015 * cBarP * t;

  final termL = dLp / (kL * sL);
  final termC = dCp / (kC * sC);
  final termH = dHp / (kH * sH);

  return math.sqrt(
    termL * termL + termC * termC + termH * termH + rT * termC * termH,
  );
}
