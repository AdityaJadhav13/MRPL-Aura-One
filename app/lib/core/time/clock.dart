import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The wall clock, injectable.
///
/// Home renders today's date and decides several of its states by comparing
/// the session against *now*, so a screen that calls `DateTime.now()` directly
/// is a screen whose output changes with the day. That made the Home goldens
/// fail every midnight — a golden that fails on a calendar boundary trains
/// people to regenerate goldens without looking at them, which is exactly the
/// value ADR-0010 says goldens exist to provide.
///
/// Overridden in tests with a fixed instant. Production reads the real clock,
/// which is still untrusted for measurement purposes — see the untrusted-clock
/// handling in `HomePresentation`.
final clockProvider = Provider<DateTime Function()>((_) => DateTime.now);
