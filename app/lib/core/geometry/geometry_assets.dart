import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:measurement/measurement.dart';

/// Why a packaged geometry could not be used.
enum GeometryAssetFailure {
  /// The manifest is missing or unreadable.
  manifestUnavailable,

  /// No entry in the manifest for the requested version.
  versionNotPackaged,

  /// The asset is present but its bytes do not match the manifest.
  checksumMismatch,

  /// The asset parsed but the engine rejects it.
  invalidGeometry,
}

/// Raised rather than returning a geometry that might be wrong.
final class GeometryAssetException implements Exception {
  const GeometryAssetException(this.failure, this.detail);

  final GeometryAssetFailure failure;
  final String detail;

  @override
  String toString() => 'GeometryAssetException(${failure.name}): $detail';
}

/// Loads badge geometry from the packaged assets.
///
/// **Geometry is data with a version, and the version is a promise.** A stored
/// `geometryVersion` has to mean exactly one layout, or every historical
/// measurement quietly reinterprets itself. So the loader verifies the asset
/// against the manifest's SHA-256 before parsing it, and refuses on mismatch:
/// a measurement made against the wrong ROI coordinates is worse than no
/// measurement, because nothing downstream can tell.
///
/// The canonical definition lives in `measurement-engine/geometry/`; these
/// assets are generated from it by `tool/export_geometry.dart`, and CI fails
/// if they have drifted.
final class GeometryAssets {
  GeometryAssets({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const String manifestPath = 'assets/geometry/manifest.json';

  final AssetBundle _bundle;
  Map<String, Object?>? _manifest;
  final Map<String, BadgeGeometry> _cache = <String, BadgeGeometry>{};

  Future<Map<String, Object?>> _loadManifest() async {
    final cached = _manifest;
    if (cached != null) return cached;
    try {
      final text = await _bundle.loadString(manifestPath);
      final decoded = jsonDecode(text) as Map<String, Object?>;
      if (decoded['schema'] != 'doseband-geometry-manifest/1') {
        throw GeometryAssetException(
          GeometryAssetFailure.manifestUnavailable,
          'unexpected manifest schema: ${decoded['schema']}',
        );
      }
      return _manifest = decoded;
    } on GeometryAssetException {
      rethrow;
    } on Object catch (e) {
      throw GeometryAssetException(
        GeometryAssetFailure.manifestUnavailable,
        '$manifestPath could not be read: $e',
      );
    }
  }

  /// Every geometry version packaged with this build.
  Future<List<String>> availableVersions() async {
    final manifest = await _loadManifest();
    return <String>[
      for (final e
          in (manifest['geometries']! as List).cast<Map<String, Object?>>())
        e['version']! as String,
    ];
  }

  /// Loads [version], verifying it against the manifest.
  Future<BadgeGeometry> load(String version) async {
    final cached = _cache[version];
    if (cached != null) return cached;

    final manifest = await _loadManifest();
    final entries = (manifest['geometries']! as List)
        .cast<Map<String, Object?>>();
    final matching = entries.where((e) => e['version'] == version).toList();
    if (matching.isEmpty) {
      throw GeometryAssetException(
        GeometryAssetFailure.versionNotPackaged,
        'no geometry "$version" in $manifestPath; packaged: '
        '${entries.map((e) => e['version']).join(', ')}',
      );
    }
    final entry = matching.first;

    final assetPath = entry['asset']! as String;
    final data = await _bundle.load(assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );

    final digest = sha256.convert(bytes).toString();
    if (digest != entry['sha256']) {
      throw GeometryAssetException(
        GeometryAssetFailure.checksumMismatch,
        '$assetPath does not match the manifest '
        '(expected ${entry['sha256']}, got $digest). The packaged geometry '
        'has been altered or the export is stale; it is refused rather than '
        'used, because a measurement against the wrong ROI coordinates is '
        'undetectable downstream.',
      );
    }

    final BadgeGeometry geometry;
    try {
      geometry = BadgeGeometry.parse(utf8.decode(bytes));
    } on Object catch (e) {
      throw GeometryAssetException(
        GeometryAssetFailure.invalidGeometry,
        '$assetPath did not parse: $e',
      );
    }

    final problems = geometry.validate();
    if (problems.isNotEmpty) {
      throw GeometryAssetException(
        GeometryAssetFailure.invalidGeometry,
        '$assetPath is structurally invalid: ${problems.join('; ')}',
      );
    }
    if (geometry.version != version) {
      throw GeometryAssetException(
        GeometryAssetFailure.invalidGeometry,
        'asset declares version "${geometry.version}" but the manifest '
        'lists it as "$version"',
      );
    }

    return _cache[version] = geometry;
  }
}
