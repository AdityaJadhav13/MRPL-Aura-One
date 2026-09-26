import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Which layout class the available width falls into.
///
/// The one place a width is compared against a breakpoint (APP-PRODUCT-01
/// §32). Screens switch on this; they never hold a number of their own, so a
/// breakpoint moves in one edit.
enum WindowClass {
  /// Phones in portrait, 0–599. Single column, bottom navigation, cards.
  compact,

  /// Small tablets and phones in landscape, 600–719. Still bottom navigation;
  /// content is centred and width-capped.
  medium,

  /// 720 and wider. Navigation becomes a rail; dense data may become a table.
  expanded;

  static WindowClass forWidth(double width) {
    if (width >= Breakpoints.expanded) return WindowClass.expanded;
    if (width >= Breakpoints.medium) return WindowClass.medium;
    return WindowClass.compact;
  }

  /// The class of the whole window. Use [forWidth] with a `LayoutBuilder`'s
  /// constraints when a component should respond to its own space instead.
  static WindowClass of(BuildContext context) =>
      forWidth(MediaQuery.sizeOf(context).width);

  bool get usesNavigationRail => this == WindowClass.expanded;

  bool get prefersTable => this == WindowClass.expanded;
}
