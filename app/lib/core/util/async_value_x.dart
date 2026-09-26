import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The data value if this is [AsyncData], otherwise null.
///
/// A stable accessor across Riverpod versions: some expose `value`, some
/// `valueOrNull`. Pattern-matching [AsyncData] is unambiguous, so screens read
/// state through this rather than depending on either name.
extension AsyncValueX<T> on AsyncValue<T> {
  T? get dataOrNull {
    final self = this;
    return self is AsyncData<T> ? self.value : null;
  }
}
