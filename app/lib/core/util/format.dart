/// Small, dependency-free formatters for measured and traceable values.
///
/// Kept in one place so a duration or a timestamp reads the same on every
/// screen — consistency is how a reader learns to trust the numbers.
abstract final class Fmt {
  /// What is printed where a value is not available. A refusal shows this, not
  /// a zero: "0 min" is a measurement, absence is not. Single source so the
  /// readout, the traceability rows and the workflow screens agree.
  static const String noValue = '- - -';

  /// A coverage/elapsed duration: "7 h 52 min", "0 min" for a window that has
  /// genuinely just opened, and [noValue] for one that cannot be established.
  ///
  /// The null case is not the same as zero. It means the window's own bounds
  /// are not trustworthy — see [ShiftSession.coverageAt] — and a duration
  /// printed there would be an invention.
  static String duration(Duration? d) {
    if (d == null) return noValue;
    if (d.inMinutes < 1) return '0 min';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '$m min';
    if (m == 0) return '$h h';
    return '$h h $m min';
  }

  /// A wall-clock time "06:12" in 24-hour form.
  static String clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// A date "12 Sep 2026".
  static String date(DateTime t) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${t.day} ${months[t.month - 1]} ${t.year}';
  }

  /// A full timestamp for traceability rows: "12 Sep 2026 · 14:03".
  static String stamp(DateTime t) => '${date(t)} · ${clock(t)}';

  /// A dose value with a fixed one decimal, so the readout column is stable.
  static String dose(double value) => value.toStringAsFixed(1);
}
