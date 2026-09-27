import 'package:flutter/foundation.dart';

/// The DoseBand QR contract, version 1 (PRODUCT BUILD v1 §8).
///
/// ```
/// DOSEBAND:1:DB-2609-0101
/// └──┬───┘ │ └─────┬─────┘
///  scheme  │   serial (doseband_id)
///        version
/// ```
///
/// ## What version 1 carries — and why so little
///
/// Only the serial. Lot, formulation, geometry, expiry and calibration
/// applicability are **looked up** in the registry by serial, not printed:
/// a printed copy cannot be corrected after manufacture, and two copies of a
/// fact eventually disagree. The QR says *which* band; the registry says what
/// is known about it.
///
/// Integrity/authenticity (a signature over the payload) is not part of
/// version 1 — nothing signs labels yet. A later version adds it; this parser
/// then refuses version-1 labels only if the organisation decides to.
///
/// ## Versioning
///
/// A reader accepts the versions it knows and refuses the rest by name, so a
/// label printed for a newer app is "update the app", not "not a DoseBand".
abstract final class DoseBandQr {
  static const String scheme = 'DOSEBAND';
  static const int currentVersion = 1;
  static const Set<int> supportedVersions = {1};

  /// `DB-` + 4 digits (lot period) + `-` + 4 digits (sequence).
  static final RegExp serialV1 = RegExp(r'^DB-\d{4}-\d{4}$');

  static String encode(String dosebandId) {
    if (!serialV1.hasMatch(dosebandId)) {
      throw ArgumentError.value(dosebandId, 'dosebandId', 'not a v1 serial');
    }
    return '$scheme:$currentVersion:$dosebandId';
  }

  static QrReading parse(String raw) {
    final text = raw.trim();
    final parts = text.split(':');
    if (parts.length < 2 || parts.first.toUpperCase() != scheme) {
      return const QrNotDoseBand();
    }
    final version = int.tryParse(parts[1]);
    if (version == null) return const QrMalformed('The version is missing.');
    if (!supportedVersions.contains(version)) {
      return QrUnsupportedVersion(version);
    }
    if (parts.length != 3) {
      return const QrMalformed('The label has the wrong number of parts.');
    }
    final serial = parts[2].toUpperCase();
    if (!serialV1.hasMatch(serial)) {
      return const QrMalformed(
        'The serial number is not in the DoseBand form.',
      );
    }
    return QrDoseBand(dosebandId: serial, version: version);
  }

  /// A serial typed by hand (the fallback when a label will not scan).
  static String? normaliseTyped(String typed) {
    final s = typed.trim().toUpperCase();
    if (serialV1.hasMatch(s)) return s;
    // Accept the digits with or without the dash, e.g. "DB 2609 0101".
    final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 8 && s.startsWith('DB')) {
      return 'DB-${digits.substring(0, 4)}-${digits.substring(4)}';
    }
    return null;
  }
}

/// What a scanned code turned out to be.
@immutable
sealed class QrReading {
  const QrReading();
}

final class QrDoseBand extends QrReading {
  const QrDoseBand({required this.dosebandId, required this.version});
  final String dosebandId;
  final int version;
}

/// A DoseBand label from a version this app does not read.
final class QrUnsupportedVersion extends QrReading {
  const QrUnsupportedVersion(this.version);
  final int version;
}

/// Claims to be a DoseBand label but is not well-formed.
final class QrMalformed extends QrReading {
  const QrMalformed(this.reason);
  final String reason;
}

/// Some other QR code entirely.
final class QrNotDoseBand extends QrReading {
  const QrNotDoseBand();
}
