import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';

/// An empty state: an outline icon, a plain statement of the state, and — where
/// there is one — the correct next action. An empty screen is an invitation to
/// act, not a dead end (directive §58).
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final t = context.type;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: c.textSecondary),
            const SizedBox(height: Space.base),
            Text(
              title,
              textAlign: TextAlign.center,
              style: t.heading.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: Space.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: t.body.copyWith(color: c.textSecondary),
            ),
            if (action != null) ...[const SizedBox(height: Space.lg), action!],
          ],
        ),
      ),
    );
  }
}

/// A detail route reached without the record it exists to display.
///
/// ## Why this exists
///
/// Twelve detail routes are handed their subject through `GoRouterState.extra`
/// — a measurement record, a worker, a report definition. `extra` is carried
/// in memory by the navigation call that pushed the route, and it is *not*
/// part of the URL. So it is absent whenever the route is reached any other
/// way: a typed or deep-linked address, a cold-start restore of the last
/// location, a browser back button on web.
///
/// Those routes previously wrote `state.extra! as T`, which threw. A crash is
/// the worst possible answer here, because the honest answer is mundane and
/// easy to state: this screen needs a record, you arrived without one, here is
/// the list to pick from. That is what this renders.
///
/// It is deliberately not an error page. Nothing has gone wrong with the
/// system; the link simply does not carry enough to identify a record.
class MissingRouteContextScreen extends StatelessWidget {
  const MissingRouteContextScreen({
    required this.what,
    required this.returnLabel,
    required this.onReturn,
    super.key,
  });

  /// The subject the route needs, as a noun phrase: "a measurement record".
  final String what;

  /// The label of the list this screen sends the user to.
  final String returnLabel;

  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nothing selected')),
      body: EmptyState(
        icon: Icons.filter_none_outlined,
        title: 'No record selected',
        message:
            'This screen shows $what, and this link does not identify one. '
            'That usually means the address was opened directly or restored '
            'from an earlier session rather than reached by choosing a record.',
        action: FilledButton(
          onPressed: onReturn,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, kMinTouchTarget),
          ),
          child: Text(returnLabel),
        ),
      ),
    );
  }
}
