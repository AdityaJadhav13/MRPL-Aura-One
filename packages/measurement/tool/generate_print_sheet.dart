// Emits an A4 print sheet carrying several Badge V1 specimens, a long scale
// bar, and a record block the operator fills in by hand.
//
//   dart run tool/generate_print_sheet.dart > geometry/badge-v1-sheet.svg
//
// This is a *tool*, not engine code. It draws from the canonical geometry and
// changes no measurement behaviour.
//
// ## Why a sheet rather than one badge per page
//
// Directive §50: printing more than one specimen is what separates camera
// variation from printer/specimen variation. If every capture uses the same
// piece of paper, a print defect is indistinguishable from a reader defect,
// and the reader gets blamed for the printer.
//
// ## Why the 100 mm bar
//
// Directive §8 requires measuring the print before photographing anything. The
// badge's own 20 mm bar is enough to catch gross rescaling; a 100 mm bar
// across the sheet resolves a 1% error to a visible millimetre, which is the
// order of error "fit to page" and driver margin-scaling actually produce.
//
// ## Why the record block is printed on the sheet
//
// §7 wants printer, paper, mode, date and measured width recorded. Written on
// the artefact itself, those facts cannot drift apart from the specimen they
// describe — which is exactly what happens when they live in a separate file.

import 'dart:io';

import 'package:measurement/measurement.dart';
import 'package:measurement/testing.dart';

String hex(List<int> rgb) =>
    '#${rgb.map((v) => v.toRadixString(16).padLeft(2, '0')).join()}';

// A4 at 1:1 millimetre scale.
const double pageWidthMm = 210;
const double pageHeightMm = 297;
const double marginMm = 12;

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
      'width="${pageWidthMm}mm" height="${pageHeightMm}mm" '
      'viewBox="0 0 $pageWidthMm $pageHeightMm">',
    )
    ..writeln('<!-- ${geometry.version} print sheet.')
    ..writeln('     PRINT AT 100% / ACTUAL SIZE.')
    ..writeln('     Disable: fit to page, shrink to fit, scale to margins.')
    ..writeln('     Then MEASURE the 100 mm bar before photographing.')
    ..writeln('')
    ..writeln('     Reference patch values are DESIGN-SPACE values and are NOT')
    ..writeln('     physical colour ground truth. A print is not a measured')
    ..writeln('     colour. See research/dossier-v0-results.md. -->')
    ..writeln(
      '<rect x="0" y="0" width="$pageWidthMm" height="$pageHeightMm" '
      'fill="#ffffff"/>',
    );

  // ---------------------------------------------------------------- header
  b
    ..writeln(
      '<text x="$marginMm" y="${marginMm + 4}" font-family="monospace" '
      'font-size="4.2" font-weight="bold" fill="#111111">'
      'DoseBand ${geometry.version} — M0C print sheet</text>',
    )
    ..writeln(
      '<text x="$marginMm" y="${marginMm + 9}" font-family="monospace" '
      'font-size="2.8" fill="#111111">'
      'PRINT AT 100%. Disable fit-to-page. Measure the 100 mm bar below '
      'before photographing.</text>',
    )
    ..writeln(
      '<text x="$marginMm" y="${marginMm + 13}" font-family="monospace" '
      'font-size="2.8" fill="#444444">'
      'Badge is ${geometry.widthMm} x ${geometry.heightMm} mm. '
      'A colour printer is required: 6 of 10 reference patches are '
      'chromatic.</text>',
    );

  // ------------------------------------------------------- the 100 mm bar
  const barY = marginMm + 20.0;
  b.writeln(
    '<rect x="$marginMm" y="$barY" width="100" height="0.8" fill="#111111"/>',
  );
  for (var mm = 0; mm <= 100; mm += 10) {
    final tall = mm % 50 == 0;
    b
      ..writeln(
        '<rect x="${marginMm + mm - 0.15}" y="${barY - (tall ? 3.0 : 1.8)}" '
        'width="0.3" height="${tall ? 3.0 : 1.8}" fill="#111111"/>',
      )
      ..writeln(
        '<text x="${marginMm + mm}" y="${barY - (tall ? 3.8 : 2.6)}" '
        'font-family="monospace" font-size="2.2" text-anchor="middle" '
        'fill="#111111">$mm</text>',
      );
  }
  b.writeln(
    '<text x="${marginMm + 104}" y="${barY + 1}" font-family="monospace" '
    'font-size="2.6" fill="#111111">'
    '100 mm — if this measures otherwise, the print is rescaled</text>',
  );

  // ------------------------------------------------------------ specimens
  //
  // Three specimens per row, laid out with enough gap to cut them apart. Each
  // is individually numbered: §50's specimen_id has to be readable on the
  // artefact, or a capture cannot be traced back to the piece of paper it
  // photographed.
  const gapMm = 8.0;
  final perRow =
      ((pageWidthMm - 2 * marginMm + gapMm) / (geometry.widthMm + gapMm))
          .floor();
  const firstRowY = barY + 14.0;
  // Four, not six. Enough to separate specimen variation from camera
  // variation (§50), while leaving the record block room to fit on the page
  // — at six, the last field fell off the bottom.
  const specimens = 4;

  for (var i = 0; i < specimens; i++) {
    final col = i % perRow;
    final row = i ~/ perRow;
    final ox = marginMm + col * (geometry.widthMm + gapMm);
    final oy = firstRowY + row * (geometry.heightMm + gapMm + 6);

    b.writeln('<g transform="translate($ox, $oy)">');
    _badge(b, geometry, 'S${i + 1}');
    b.writeln('</g>');
  }

  // --------------------------------------------------------- record block
  //
  // §7 wants these recorded. Printed here so they stay attached to the
  // specimens they describe.
  final blockY =
      firstRowY +
      ((specimens / perRow).ceil()) * (geometry.heightMm + gapMm + 6) +
      6;

  b.writeln(
    '<text x="$marginMm" y="$blockY" font-family="monospace" '
    'font-size="3.2" font-weight="bold" fill="#111111">'
    'PRINT RECORD — complete by hand before capture</text>',
  );

  final fields = <String>[
    'Printer make / model',
    'Printer technology (laser / inkjet)',
    'Colour or monochrome',
    'Paper type and finish',
    'Print quality mode',
    'Colour mode / ICC profile',
    'Software used to print',
    'Requested scale (must be 100%)',
    'Date printed',
    'MEASURED length of the 100 mm bar',
    'MEASURED badge width (expected ${geometry.widthMm} mm)',
    'MEASURED badge height (expected ${geometry.heightMm} mm)',
    'Scale error (measured / expected)',
    'Operator',
  ];

  for (var i = 0; i < fields.length; i++) {
    final y = blockY + 6.5 + i * 5.4;
    // Loudly, not silently. A field that quietly falls off the page is a
    // field the operator never fills in and nobody notices is missing.
    if (y > pageHeightMm - marginMm) {
      stderr.writeln(
        'print sheet: "${fields[i]}" and ${fields.length - i - 1} further '
        'field(s) do not fit on the page. Reduce the specimen count.',
      );
      exit(1);
    }
    b
      ..writeln(
        '<text x="$marginMm" y="$y" font-family="monospace" font-size="2.6" '
        'fill="#111111">${fields[i]}</text>',
      )
      ..writeln(
        '<rect x="${marginMm + 72}" y="${y + 0.8}" '
        'width="${pageWidthMm - 2 * marginMm - 72}" height="0.2" '
        'fill="#999999"/>',
      );
  }

  b.writeln('</svg>');
  stdout.write(b);
}

/// One badge specimen, drawn from the canonical geometry, with its id.
void _badge(StringBuffer b, BadgeGeometry geometry, String specimenId) {
  b.writeln(
    '<rect x="0" y="0" width="${geometry.widthMm}" '
    'height="${geometry.heightMm}" '
    'fill="${hex(badgeV1Colours['substrate']!)}"/>',
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

  // Cut line, outside the badge so it does not intrude on any ROI.
  b.writeln(
    '<rect x="-0.4" y="-0.4" width="${geometry.widthMm + 0.8}" '
    'height="${geometry.heightMm + 0.8}" fill="none" stroke="#bbbbbb" '
    'stroke-width="0.2" stroke-dasharray="1 1"/>',
  );

  // Specimen id and version, printed below the cut line so they are readable
  // on the artefact but never inside the imaged area.
  b.writeln(
    '<text x="0" y="${geometry.heightMm + 4}" font-family="monospace" '
    'font-size="2.4" fill="#111111">'
    '$specimenId  ${geometry.version}</text>',
  );
}
