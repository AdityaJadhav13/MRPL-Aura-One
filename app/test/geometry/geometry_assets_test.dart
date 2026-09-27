import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/geometry/geometry_assets.dart';
import 'package:measurement/measurement.dart';

/// Serves whatever we hand it, so tampering can be staged.
class _StubBundle extends CachingAssetBundle {
  _StubBundle(this.files);

  final Map<String, Uint8List> files;

  @override
  Future<ByteData> load(String key) async {
    final bytes = files[key];
    if (bytes == null) throw FlutterError('asset not found: $key');
    return ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);
  }
}

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

String _manifestFor(String assetPath, String version, Uint8List bytes) =>
    jsonEncode(<String, Object?>{
      'schema': 'doseband-geometry-manifest/1',
      'geometries': <Map<String, Object?>>[
        <String, Object?>{
          'version': version,
          'asset': assetPath,
          'sha256': sha256.convert(bytes).toString(),
          'bytes': bytes.length,
        },
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final canonical = File(
    '../measurement-engine/geometry/badge-v1.geometry.json',
  ).readAsStringSync();

  group('the packaged asset matches the canonical geometry', () {
    test('badge-v1 loads from the real bundle and is byte-identical to '
        'the canonical source', () async {
      final assets = GeometryAssets();
      final geometry = await assets.load('badge-v1-research');

      expect(geometry.version, 'badge-v1-research');
      expect(geometry.validate(), isEmpty);

      // The strong claim: not "equivalent", identical.
      final packaged = await rootBundle.loadString(
        'assets/geometry/badge-v1-research.json',
      );
      expect(
        packaged,
        canonical,
        reason:
            'the exported asset has drifted from '
            'measurement-engine/geometry/ — re-run '
            'dart run tool/export_geometry.dart',
      );
    });

    test('both geometries are packaged and listed', () async {
      final versions = await GeometryAssets().availableVersions();
      expect(
        versions,
        containsAll(<String>['badge-v1-research', 'demo-badge-v0']),
      );
    });

    test('badge v1 carries the redundant control points M0B added', () async {
      final geometry = await GeometryAssets().load('badge-v1-research');
      expect(geometry.primaryFiducials, hasLength(4));
      expect(geometry.secondaryFiducials, hasLength(6));
      expect(geometry.supportsDeformationValidation, isTrue);
      expect(geometry.ofKind(RoiKind.reference), hasLength(10));
    });

    test('a loaded geometry is cached, not re-read', () async {
      final assets = GeometryAssets();
      final a = await assets.load('badge-v1-research');
      final b = await assets.load('badge-v1-research');
      expect(identical(a, b), isTrue);
    });
  });

  group('a geometry that might be wrong is refused, not used', () {
    test('tampered bytes fail the checksum', () async {
      final tampered = canonical.replaceFirst('"x_mm": 11.0', '"x_mm": 13.0');
      expect(tampered, isNot(canonical));

      // The manifest still carries the ORIGINAL digest.
      final bundle = _StubBundle(<String, Uint8List>{
        GeometryAssets.manifestPath: _bytes(
          _manifestFor(
            'assets/geometry/badge-v1-research.json',
            'badge-v1-research',
            _bytes(canonical),
          ),
        ),
        'assets/geometry/badge-v1-research.json': _bytes(tampered),
      });

      await expectLater(
        GeometryAssets(bundle: bundle).load('badge-v1-research'),
        throwsA(
          isA<GeometryAssetException>().having(
            (e) => e.failure,
            'failure',
            GeometryAssetFailure.checksumMismatch,
          ),
        ),
      );
    });

    test('an unpackaged version is refused rather than substituted', () async {
      await expectLater(
        GeometryAssets().load('badge-v9-does-not-exist'),
        throwsA(
          isA<GeometryAssetException>().having(
            (e) => e.failure,
            'failure',
            GeometryAssetFailure.versionNotPackaged,
          ),
        ),
      );
    });

    test('an asset whose declared version disagrees with the manifest is '
        'refused', () async {
      final bytes = _bytes(canonical);
      final bundle = _StubBundle(<String, Uint8List>{
        GeometryAssets.manifestPath: _bytes(
          _manifestFor(
            'assets/geometry/mislabelled.json',
            'badge-v2-claimed',
            bytes,
          ),
        ),
        'assets/geometry/mislabelled.json': bytes,
      });

      await expectLater(
        GeometryAssets(bundle: bundle).load('badge-v2-claimed'),
        throwsA(
          isA<GeometryAssetException>().having(
            (e) => e.failure,
            'failure',
            GeometryAssetFailure.invalidGeometry,
          ),
        ),
      );
    });

    test('a structurally invalid geometry is refused even with a good '
        'checksum', () async {
      const broken =
          '{"version":"broken","width_mm":40,"height_mm":25,'
          '"fiducials":[],"rois":[]}';
      final bytes = _bytes(broken);
      final bundle = _StubBundle(<String, Uint8List>{
        GeometryAssets.manifestPath: _bytes(
          _manifestFor('assets/geometry/broken.json', 'broken', bytes),
        ),
        'assets/geometry/broken.json': bytes,
      });

      await expectLater(
        GeometryAssets(bundle: bundle).load('broken'),
        throwsA(
          isA<GeometryAssetException>().having(
            (e) => e.failure,
            'failure',
            GeometryAssetFailure.invalidGeometry,
          ),
        ),
      );
    });

    test('a missing manifest is a refusal, not an empty list', () async {
      final bundle = _StubBundle(<String, Uint8List>{});
      await expectLater(
        GeometryAssets(bundle: bundle).availableVersions(),
        throwsA(
          isA<GeometryAssetException>().having(
            (e) => e.failure,
            'failure',
            GeometryAssetFailure.manifestUnavailable,
          ),
        ),
      );
    });
  });
}
