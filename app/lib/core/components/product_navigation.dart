import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/product_colors.dart';
import '../design/responsive.dart';
import '../design/theme.dart';
import '../design/tokens.dart';

/// One destination in a workspace's primary navigation.
@immutable
class ProductDestination {
  const ProductDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.isPrimaryAction = false,
  });

  /// Always shown. A destination is never an icon alone (§16).
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// The workspace's one physical action — Scan, for a worker. Drawn as the
  /// dominant control in the bar. It is still a destination: what the action
  /// *does* is resolved by the screen it opens, from the worker's current
  /// state, never encoded in the navigation widget (§58).
  final bool isPrimaryAction;
}

/// The five workspaces and their target primary navigation (§30).
///
/// **Only [worker] is wired in APP-PRODUCT-01.** The others are the approved
/// targets, held as data so the phase that builds each workspace (P6–P9)
/// picks up a decided structure instead of inventing one. The HSE shell that
/// exists today predates this and keeps its own four destinations until P7.
abstract final class WorkspaceDestinations {
  static const List<ProductDestination> worker = [
    ProductDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    ProductDestination(
      label: 'History',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
    ),
    ProductDestination(
      label: 'Scan',
      icon: Icons.qr_code_scanner,
      selectedIcon: Icons.qr_code_scanner,
      isPrimaryAction: true,
    ),
    ProductDestination(
      label: 'Safety',
      icon: Icons.health_and_safety_outlined,
      selectedIcon: Icons.health_and_safety,
    ),
    ProductDestination(
      label: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
  ];

  /// Target (P6). Not wired.
  static const List<ProductDestination> supervisor = [
    ProductDestination(
      label: 'Overview',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
    ),
    ProductDestination(
      label: 'Team',
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups,
    ),
    ProductDestination(
      label: 'Monitoring',
      icon: Icons.sensors_outlined,
      selectedIcon: Icons.sensors,
    ),
    ProductDestination(
      label: 'Exceptions',
      icon: Icons.report_outlined,
      selectedIcon: Icons.report,
    ),
    ProductDestination(
      label: 'More',
      icon: Icons.menu,
      selectedIcon: Icons.menu_open,
    ),
  ];

  /// Target (P7). Not wired; the current HSE shell keeps its own until then.
  static const List<ProductDestination> hse = [
    ProductDestination(
      label: 'Overview',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
    ),
    ProductDestination(
      label: 'Exposures',
      icon: Icons.table_rows_outlined,
      selectedIcon: Icons.table_rows,
    ),
    ProductDestination(
      label: 'Reviews',
      icon: Icons.fact_check_outlined,
      selectedIcon: Icons.fact_check,
    ),
    ProductDestination(
      label: 'Reports',
      icon: Icons.description_outlined,
      selectedIcon: Icons.description,
    ),
    ProductDestination(
      label: 'More',
      icon: Icons.menu,
      selectedIcon: Icons.menu_open,
    ),
  ];

  /// Target (P8). Not wired. De-identified by default.
  static const List<ProductDestination> management = [
    ProductDestination(
      label: 'Overview',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
    ),
    ProductDestination(
      label: 'Monitoring',
      icon: Icons.sensors_outlined,
      selectedIcon: Icons.sensors,
    ),
    ProductDestination(
      label: 'Trends',
      icon: Icons.show_chart_outlined,
      selectedIcon: Icons.show_chart,
    ),
    ProductDestination(
      label: 'Reports',
      icon: Icons.description_outlined,
      selectedIcon: Icons.description,
    ),
    ProductDestination(
      label: 'More',
      icon: Icons.menu,
      selectedIcon: Icons.menu_open,
    ),
  ];

  /// Target (P9). Not wired. No identified occupational data.
  static const List<ProductDestination> admin = [
    ProductDestination(
      label: 'Overview',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
    ),
    ProductDestination(
      label: 'People',
      icon: Icons.manage_accounts_outlined,
      selectedIcon: Icons.manage_accounts,
    ),
    ProductDestination(
      label: 'DoseBands',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
    ),
    ProductDestination(
      label: 'System',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
    ProductDestination(
      label: 'More',
      icon: Icons.menu,
      selectedIcon: Icons.menu_open,
    ),
  ];
}

/// Primary navigation that adapts to the window: a floating bar at the foot of
/// a phone, a rail down the side of a wide window (§32).
///
/// Both read the same [selectedIndex], so the selection survives a rotation
/// or a resize that crosses the breakpoint. The breakpoint itself is
/// [WindowClass] — this widget holds no number of its own.
class AdaptiveNavigationScaffold extends StatelessWidget {
  const AdaptiveNavigationScaffold({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.body,
    super.key,
  });

  final List<ProductDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final window = WindowClass.of(context);

    if (window.usesNavigationRail) {
      return Scaffold(
        backgroundColor: p.surfacePage,
        body: Row(
          children: [
            ProductNavigationRail(
              destinations: destinations,
              selectedIndex: selectedIndex,
              onSelected: onSelected,
            ),
            VerticalDivider(width: Borders.hairline, color: p.borderSubtle),
            Expanded(child: body),
          ],
        ),
      );
    }

    // The keyboard covers the bottom of the screen. The bar steps aside while
    // it is up, so it can never sit between a field and the keyboard, and the
    // screen underneath does its own inset handling (§24, §67).
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: p.surfacePage,
      // The destination screens are Scaffolds that resize for the keyboard
      // themselves. Resizing here as well would remove the inset twice.
      resizeToAvoidBottomInset: false,
      body: body,
      // The bar lives in the bottom slot rather than floating over the body,
      // so content can never scroll *under* it: the last item of any list
      // always clears it without each screen adding padding (§31).
      bottomNavigationBar: keyboardUp
          ? null
          : FloatingNavigationBar(
              destinations: destinations,
              selectedIndex: selectedIndex,
              onSelected: onSelected,
            ),
    );
  }
}

/// The floating bottom navigation surface (§31).
///
/// White, a hairline border and the one neutral shadow the product allows. The
/// primary-action destination is the only filled element; everything else is
/// neutral until selected, when it takes the brand green on a pale
/// indicator. No gradient, no glow, no bounce.
class FloatingNavigationBar extends StatelessWidget {
  const FloatingNavigationBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<ProductDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Navigation labels grow with the user's text size up to this factor and
  /// no further. Five labels across a 320-point phone at 200% cannot all be
  /// read; at 130% they can, and a label that has stopped growing is better
  /// than one that has been clipped (§25).
  static const double maxLabelScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final p = context.product;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: maxLabelScale,
      child: SafeArea(
        top: false,
        // The gesture bar or the three-button bar sits below this. The margin
        // is the floating gap, added on top of whatever inset the system
        // reserves, so the bar never touches the system navigation (§24).
        minimum: const EdgeInsets.only(bottom: Space.sm),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.md,
            Space.xs,
            Space.md,
            Space.xs,
          ),
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            label: 'Main navigation',
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: p.surfaceCard,
                borderRadius: BorderRadius.circular(Radii.lg),
                border: Border.all(color: p.borderSubtle),
                boxShadow: Elevation.floating,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.xs,
                  vertical: Space.xs,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (var i = 0; i < destinations.length; i++)
                      Expanded(
                        child: _BarItem(
                          destination: destinations[i],
                          selected: i == selectedIndex,
                          onTap: () => _select(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _select(int index) {
    HapticFeedback.selectionClick();
    onSelected(index);
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final ProductDestination destination;
  final bool selected;
  final VoidCallback onTap;

  Widget _indicator(ProductColors p, Duration duration, bool selected) =>
      AnimatedContainer(
        duration: duration,
        curve: Curves.easeOut,
        width: 52,
        height: 32,
        decoration: BoxDecoration(
          color: selected ? p.brandPrimaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Icon(
          selected ? destination.selectedIcon : destination.icon,
          size: 24,
          color: selected ? p.onBrandContainer : p.textSecondary,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final t = context.type;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion ? Duration.zero : Motion.control;
    final primary = destination.isPrimaryAction;

    final Widget glyph;
    if (primary) {
      // The dominant control: a filled brand circle. Same size selected or
      // not — it is the action, not a tab that lights up. Kept inside the bar
      // rather than breaking out above it, so it can never cover content.
      glyph = Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: p.brandPrimary,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: p.brandPrimaryContainer, width: 3)
              : null,
        ),
        child: Icon(destination.icon, size: 24, color: p.onBrandPrimary),
      );
    } else {
      // Held in the same 44-point slot as the Scan circle, so all five labels
      // sit on one baseline.
      glyph = SizedBox(
        height: 44,
        child: Center(child: _indicator(p, duration, selected)),
      );
    }

    final labelColour = selected || primary
        ? p.onBrandContainer
        : p.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: destination.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: ConstrainedBox(
          // Every destination is at least a gloved thumb wide and tall.
          constraints: const BoxConstraints(minHeight: kMinTouchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                glyph,
                const SizedBox(height: 2),
                // A long label (or a longer language) shrinks to fit its slot
                // rather than overflowing into its neighbour.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    style: t.caption.copyWith(
                      color: labelColour,
                      fontWeight: selected || primary
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The wide-window form of the same navigation.
class ProductNavigationRail extends StatelessWidget {
  const ProductNavigationRail({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<ProductDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.product;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: FloatingNavigationBar.maxLabelScale,
      child: SafeArea(
        right: false,
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.sizeOf(context).height -
                  MediaQuery.paddingOf(context).vertical,
            ),
            child: IntrinsicHeight(
              child: NavigationRail(
                selectedIndex: selectedIndex,
                onDestinationSelected: (i) {
                  HapticFeedback.selectionClick();
                  onSelected(i);
                },
                labelType: NavigationRailLabelType.all,
                groupAlignment: -0.9,
                destinations: [
                  for (final d in destinations)
                    NavigationRailDestination(
                      icon: d.isPrimaryAction
                          ? _RailPrimaryGlyph(icon: d.icon)
                          : Icon(d.icon),
                      selectedIcon: d.isPrimaryAction
                          ? _RailPrimaryGlyph(icon: d.icon)
                          : Icon(d.selectedIcon, color: p.onBrandContainer),
                      label: Text(d.label),
                      padding: const EdgeInsets.symmetric(vertical: Space.xs),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RailPrimaryGlyph extends StatelessWidget {
  const _RailPrimaryGlyph({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: p.brandPrimary, shape: BoxShape.circle),
      child: Icon(icon, size: 22, color: p.onBrandPrimary),
    );
  }
}
