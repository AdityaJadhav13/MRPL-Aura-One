import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/core/env/app_info.dart';
import 'package:h2s_doseband/core/env/app_version.dart';

void main() {
  test('a flavour suffix is not a version mismatch', () {
    final parts = appVersion.split('+');
    final dev = InstalledPackage(
      appName: 'DoseBand Dev',
      packageName: 'in.doseband.h2s.dev',
      version: '${parts[0]}-dev',
      buildNumber: parts[1],
    );
    expect(dev.matchesStamp, isTrue);
    final other = InstalledPackage(
      appName: 'x',
      packageName: 'x',
      version: '9.9.9',
      buildNumber: '1',
    );
    expect(other.matchesStamp, isFalse);
  });
}
