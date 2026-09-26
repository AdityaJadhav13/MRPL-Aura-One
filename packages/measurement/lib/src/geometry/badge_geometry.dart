import 'dart:convert';

import 'package:meta/meta.dart';

/// A point in canonical badge space, in millimetres from the badge origin
/// (top-left), x to the right and y downward.
@immutable
final class PointMm {
  const PointMm(this.x, this.y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      other is PointMm && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'PointMm($x, $y)';
}

/// A point in source-image pixel coordinates.
@immutable
final class PointPx {
  const PointPx(this.x, this.y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      other is PointPx && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'PointPx($x, $y)';
}

/// What a region of the badge is for.
///
/// The kind drives which checks apply to it, so it is an enum rather than a
/// free-text label: a typo in a geometry file must fail to parse, not silently
/// create a region nothing validates.
enum RoiKind {
  /// An active sensing window.
  sensor,

  /// A protected control region, shielded from the analyte, used to separate
  /// non-analyte ageing and environmental drift from a real response.
  blank,

  /// An age or shelf-life indicator.
  expiry,

  /// A printed colour reference patch.
  reference,

  /// The badge identifier region.
  identifier,
}

/// A rectangular region in canonical badge millimetre space.
@immutable
final class RoiDefinition {
  const RoiDefinition({
    required this.id,
    required this.kind,
    required this.xMm,
    required this.yMm,
    required this.widthMm,
    required this.heightMm,
    this.erosionMm = 0.5,
  }) : assert(widthMm > 0, 'ROI width must be positive'),
       assert(heightMm > 0, 'ROI height must be positive'),
       assert(erosionMm >= 0, 'erosion cannot be negative');

  final String id;
  final RoiKind kind;
  final double xMm;
  final double yMm;
  final double widthMm;
  final double heightMm;

  /// How far to shrink the region inward before sampling.
  ///
  /// Print registration is not perfect and edges carry both the printed
  /// boundary and any contamination creeping in from it. QRsens shrinks its
  /// detected circles by 20% for the same reason
  /// (doi:10.1016/j.snb.2022.133001).
  final double erosionMm;

  /// The region actually sampled, after erosion.
  ///
  /// Returns null when erosion would consume the region — which is a geometry
  /// authoring error, and is surfaced rather than clamped.
  RoiDefinition? get eroded {
    final w = widthMm - 2 * erosionMm;
    final h = heightMm - 2 * erosionMm;
    if (w <= 0 || h <= 0) return null;
    return RoiDefinition(
      id: id,
      kind: kind,
      xMm: xMm + erosionMm,
      yMm: yMm + erosionMm,
      widthMm: w,
      heightMm: h,
      erosionMm: 0,
    );
  }

  bool containsMm(PointMm p) =>
      p.x >= xMm && p.x <= xMm + widthMm && p.y >= yMm && p.y <= yMm + heightMm;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'kind': kind.name,
    'x_mm': xMm,
    'y_mm': yMm,
    'width_mm': widthMm,
    'height_mm': heightMm,
    'erosion_mm': erosionMm,
  };

  static RoiDefinition fromJson(Map<String, Object?> json) => RoiDefinition(
    id: json['id']! as String,
    kind: RoiKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => throw FormatException('unknown ROI kind: ${json['kind']}'),
    ),
    xMm: (json['x_mm']! as num).toDouble(),
    yMm: (json['y_mm']! as num).toDouble(),
    widthMm: (json['width_mm']! as num).toDouble(),
    heightMm: (json['height_mm']! as num).toDouble(),
    erosionMm: (json['erosion_mm'] as num?)?.toDouble() ?? 0.5,
  );
}

/// What a geometric marker is for.
///
/// The split is load-bearing, not cosmetic. A planar homography has eight
/// degrees of freedom and four point correspondences supply exactly eight
/// equations, so the four points used to fit the pose are reproduced with zero
/// residual **by construction** — their residual carries no information about
/// whether the badge is flat. Only markers withheld from the fit can say that.
///
/// See `docs/computer-vision/pipeline.md` §2.1.
enum FiducialRole {
  /// Used to estimate the pose. Residual on these is structurally zero.
  primary,

  /// Deliberately **withheld** from the pose estimate, and used only to
  /// evaluate it: reprojection residual, local deformation, print distortion,
  /// partial marker corruption.
  secondary,
}

/// A fiducial marker at a known position in canonical badge space.
@immutable
final class FiducialDefinition {
  const FiducialDefinition({
    required this.id,
    required this.centreMm,
    required this.sizeMm,
    this.orientationMarker = false,
    this.role = FiducialRole.primary,
  });

  final String id;
  final PointMm centreMm;
  final double sizeMm;

  /// Whether this marker takes part in the pose fit or validates it.
  final FiducialRole role;

  /// Exactly one fiducial is asymmetric, which is what resolves the badge's
  /// rotation. Without it a square arrangement has a four-fold ambiguity and
  /// the pipeline can rectify a perfectly sharp image of the wrong
  /// orientation.
  final bool orientationMarker;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'centre_mm': <double>[centreMm.x, centreMm.y],
    'size_mm': sizeMm,
    'orientation_marker': orientationMarker,
    'role': role.name,
  };

  static FiducialDefinition fromJson(Map<String, Object?> json) {
    final centre = (json['centre_mm']! as List).cast<num>();
    final roleName = json['role'] as String?;
    return FiducialDefinition(
      id: json['id']! as String,
      centreMm: PointMm(centre[0].toDouble(), centre[1].toDouble()),
      sizeMm: (json['size_mm']! as num).toDouble(),
      orientationMarker: (json['orientation_marker'] as bool?) ?? false,
      // An absent role means primary, so a geometry authored before the
      // primary/secondary split still parses and still means what it meant.
      role: roleName == null
          ? FiducialRole.primary
          : FiducialRole.values.firstWhere(
              (r) => r.name == roleName,
              orElse: () =>
                  throw FormatException('unknown fiducial role: $roleName'),
            ),
    );
  }
}

/// The canonical, versioned description of a badge.
///
/// **Geometry is data.** No ROI coordinate may appear in Dart source; this
/// type exists to be loaded from a versioned artefact, so that changing the
/// badge layout is a data change with its own version, not a code change that
/// silently reinterprets every historical measurement
/// (`docs/architecture/data-model.md`).
@immutable
final class BadgeGeometry {
  const BadgeGeometry({
    required this.version,
    required this.widthMm,
    required this.heightMm,
    required this.fiducials,
    required this.rois,
  });

  final String version;
  final double widthMm;
  final double heightMm;
  final List<FiducialDefinition> fiducials;
  final List<RoiDefinition> rois;

  Iterable<RoiDefinition> ofKind(RoiKind kind) =>
      rois.where((r) => r.kind == kind);

  /// Markers used to estimate the pose.
  List<FiducialDefinition> get primaryFiducials =>
      fiducials.where((f) => f.role == FiducialRole.primary).toList();

  /// Markers withheld from the pose estimate, used to validate it.
  List<FiducialDefinition> get secondaryFiducials =>
      fiducials.where((f) => f.role == FiducialRole.secondary).toList();

  /// Whether this geometry carries enough withheld markers to say anything
  /// about badge flatness or print distortion.
  ///
  /// A geometry without them is still usable for measurement — it simply
  /// cannot report deformation, and must not pretend to. Three is the minimum
  /// at which a residual *pattern* exists rather than a single number.
  bool get supportsDeformationValidation => secondaryFiducials.length >= 3;

  RoiDefinition? roiById(String id) {
    for (final r in rois) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Structural problems that make this geometry unusable, as human-readable
  /// strings. Empty means usable.
  ///
  /// This is validation of the *artefact*, not of an image. A geometry file
  /// that fails here should never reach a measurement.
  List<String> validate() {
    final problems = <String>[];

    if (fiducials.length < 4) {
      problems.add(
        'needs at least 4 fiducials for a homography, found ${fiducials.length}',
      );
    }
    final orientationMarkers = fiducials
        .where((f) => f.orientationMarker)
        .length;
    if (orientationMarkers != 1) {
      problems.add(
        'needs exactly 1 primary orientation marker to resolve rotation, '
        'found $orientationMarkers',
      );
    }

    final ids = <String>{};
    for (final r in rois) {
      if (!ids.add(r.id)) problems.add('duplicate ROI id: ${r.id}');
      if (r.eroded == null) {
        problems.add('ROI ${r.id} is consumed by its own erosion margin');
      }
      if (r.xMm < 0 ||
          r.yMm < 0 ||
          r.xMm + r.widthMm > widthMm ||
          r.yMm + r.heightMm > heightMm) {
        problems.add('ROI ${r.id} falls outside the badge');
      }
    }
    for (final f in fiducials) {
      if (!ids.add(f.id)) problems.add('duplicate fiducial id: ${f.id}');
    }

    if (ofKind(RoiKind.sensor).isEmpty) {
      problems.add('no sensor ROI defined');
    }
    if (ofKind(RoiKind.reference).length < 2) {
      problems.add(
        'needs at least 2 reference patches; a correction cannot be validated '
        'without patches withheld from its own fit',
      );
    }

    return problems;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    'width_mm': widthMm,
    'height_mm': heightMm,
    'fiducials': fiducials.map((f) => f.toJson()).toList(),
    'rois': rois.map((r) => r.toJson()).toList(),
  };

  static BadgeGeometry fromJson(Map<String, Object?> json) => BadgeGeometry(
    version: json['version']! as String,
    widthMm: (json['width_mm']! as num).toDouble(),
    heightMm: (json['height_mm']! as num).toDouble(),
    fiducials: (json['fiducials']! as List)
        .cast<Map<String, Object?>>()
        .map(FiducialDefinition.fromJson)
        .toList(),
    rois: (json['rois']! as List)
        .cast<Map<String, Object?>>()
        .map(RoiDefinition.fromJson)
        .toList(),
  );

  static BadgeGeometry parse(String jsonText) =>
      fromJson(jsonDecode(jsonText) as Map<String, Object?>);
}
