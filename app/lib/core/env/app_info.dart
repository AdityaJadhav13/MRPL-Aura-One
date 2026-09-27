import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_version.dart';

/// The installed package's own metadata — name, version, build number —
/// read from the platform at runtime (PRODUCT BUILD v1 §101). About and
/// System screens show this, never a string typed into a screen.
///
/// [appVersion] is the compile-time stamp written into every capture record;
/// [InstalledPackage.matchesStamp] says whether the two agree.
final installedPackageProvider = FutureProvider<InstalledPackage>((_) async {
  final info = await PackageInfo.fromPlatform();
  return InstalledPackage(
    appName: info.appName,
    packageName: info.packageName,
    version: info.version,
    buildNumber: info.buildNumber,
  );
});

final class InstalledPackage {
  const InstalledPackage({
    required this.appName,
    required this.packageName,
    required this.version,
    required this.buildNumber,
  });

  final String appName;
  final String packageName;
  final String version;
  final String buildNumber;

  String get full => buildNumber.isEmpty ? version : '$version+$buildNumber';

  /// The flavour's version-name suffix ("-dev", "-staging") is a label, not
  /// a different version; the comparison is on the release part.
  bool get matchesStamp {
    final release = version.split('-').first;
    return (buildNumber.isEmpty ? release : '$release+$buildNumber') ==
        appVersion;
  }
}
