// Emits a print-ready SVG of a badge geometry, for dossier V0.
//
//   dart run tool/generate_printable_target.dart > geometry/badge-v1-target.svg
//
// SVG at 1:1 millimetre scale so the printed artefact measures what the
// geometry file says it measures. Print at 100% — "fit to page" silently
// rescales it and every millimetre-space conclusion drawn from the result
// would be wrong by that factor.

import 'dart:io';

import 'package:measurement/measurement.dart';
import 'package:measurement/testing.dart';

String hex(List<int> rgb) =>
    '#${rgb.map((v) => v.toRadixString(16).padLeft(2, '0')).join()}';

void main(List<String> args) {
  final path = args.isEmpty ? 'geometry/badge-v1.geometry.json' : args.first;
  final geometry = BadgeGeometry.parse(File(path).readAsStringSync());
  final problems = geometry.validate();
  if (problems.isNotEmpty) {
    stderr.writeln('geometry is invalid: $problems');
    exit(1);
  }

  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" '
      'width="${geometry.widthMm}mm" height="${geometry.heightMm}mm" '
      'viewBox="0 0 ${geometry.widthMm} ${geometry.heightMm}">',
    )
    ..writeln('<!-- ${geometry.version}. Print at 100%, no scaling. -->')
    ..writeln('<!-- Reference patch values here are DESIGN-SPACE values and')
    ..writeln('     are NOT physical colour ground truth. Measure the actual')
    ..writeln('     print with a spectrophotometer before using them as')
    ..writeln('     correction targets. See research/dossier-v0.md. -->')
    ..writeln(
      '<rect x="0" y="0" width="${geometry.widthMm}" '
      'height="${geometry.heightMm}" fill="${hex(badgeV1Colours['substrate']!)}"/>',
    );

  for (final roi in geometry.rois) {
    final colour = badgeV1Colours[roi.id];
    if (colour == null) continue;
    b.writeln(
      '<rect x="${roi.xMm}" y="${roi.yMm}" width="${roi.widthMm}" '
      'height="${roi.heightMm}" fill="${hex(colour)}"/>',
    );
  }

  for (final f in geometry.fiducials) {
    final half = f.sizeMm / 2;
    b.writeln(
      '<rect x="${f.centreMm.x - half}" y="${f.centreMm.y - half}" '
      'width="${f.sizeMm}" height="${f.sizeMm}" '
      'fill="${hex(badgeV1Colours['fiducial']!)}"/>',
    );
  }

  // A cut line and a printed scale bar. The scale bar is the cheapest possible
  // check that the print came out at 1:1 — measure it before photographing
  // anything.
  b
    ..writeln(
      '<rect x="0.1" y="0.1" width="${geometry.widthMm - 0.2}" '
      'height="${geometry.heightMm - 0.2}" fill="none" '
      'stroke="#999999" stroke-width="0.2" stroke-dasharray="1 1"/>',
    )
    ..writeln(
      '<rect x="${geometry.widthMm - 22}" y="${geometry.heightMm - 3.2}" '
      'width="20" height="0.6" fill="#111111"/>',
    )
    ..writeln(
      '<text x="${geometry.widthMm - 22}" y="${geometry.heightMm - 1.4}" '
      'font-family="monospace" font-size="1.6" fill="#111111">'
      '20 mm - verify with a ruler</text>',
    )
    ..writeln('</svg>');

  stdout.write(b);
}
