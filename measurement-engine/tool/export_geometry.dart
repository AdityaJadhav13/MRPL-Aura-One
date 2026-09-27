// Exports the canonical badge geometry into the Flutter app as an asset.
//
//   dart run tool/export_geometry.dart
//
// The canonical definition lives in `measurement-engine/geometry/`. The app
// cannot read it from there at runtime — a Flutter asset must live inside the
// app package — so it is **exported**, never copied by hand.
//
// CI re-runs this and fails if the result differs from what is committed, so
// the packaged asset cannot drift from the canonical definition silently.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:measurement/measurement.dart';

const String canonicalDirectory = 'geometry';
const String exportDirectory = '../app/assets/geometry';

void main() {
  final source = Directory(canonicalDirectory);
  if (!source.existsSync()) {
    stderr.writeln(
      'canonical geometry directory not found: $canonicalDirectory',
    );
    exit(1);
  }

  final target = Directory(exportDirectory);
  if (target.existsSync()) {
    target.deleteSync(recursive: true);
  }
  target.createSync(recursive: true);

  final entries = <Map<String, Object?>>[];
  final files =
      source
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.geometry.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final text = file.readAsStringSync();

    // Parse and validate before exporting. Shipping a geometry the engine
    // would reject at runtime is a build-time failure, not a field one.
    final BadgeGeometry geometry;
    try {
      geometry = BadgeGeometry.parse(text);
    } on Object catch (e) {
      stderr.writeln('${file.path} does not parse: $e');
      exit(1);
    }
    final problems = geometry.validate();
    if (problems.isNotEmpty) {
      stderr.writeln('${file.path} is invalid: ${problems.join('; ')}');
      exit(1);
    }

    final assetName = '${geometry.version}.json';
    final bytes = utf8.encode(text);
    File('$exportDirectory/$assetName').writeAsBytesSync(bytes);

    entries.add(<String, Object?>{
      'version': geometry.version,
      'asset': 'assets/geometry/$assetName',
      'source': '$canonicalDirectory/${file.uri.pathSegments.last}',
      'sha256': sha256.convert(bytes).toString(),
      'bytes': bytes.length,
      'width_mm': geometry.widthMm,
      'height_mm': geometry.heightMm,
      'primary_fiducials': geometry.primaryFiducials.length,
      'secondary_fiducials': geometry.secondaryFiducials.length,
      'supports_deformation_validation': geometry.supportsDeformationValidation,
      'reference_patches': geometry.ofKind(RoiKind.reference).length,
    });
    stdout.writeln('exported ${geometry.version} (${bytes.length} bytes)');
  }

  if (entries.isEmpty) {
    stderr.writeln('no geometry files found to export');
    exit(1);
  }

  final manifest = <String, Object?>{
    'schema': 'doseband-geometry-manifest/1',
    'generated_by': 'measurement-engine/tool/export_geometry.dart',
    'note':
        'Generated. Do not edit. The canonical source is '
        'measurement-engine/geometry/; see its README.',
    'geometries': entries,
  };
  File('$exportDirectory/manifest.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
  );
  stdout.writeln('wrote $exportDirectory/manifest.json');
}
