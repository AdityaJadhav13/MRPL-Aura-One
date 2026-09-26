import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';

/// A quiet, non-alarming note. A left rule in the instrument's own colour, an
/// outline icon, and plain text.
///
/// This is where the product's single most important honesty lives — the
/// reminder that a passive badge is not a real-time alarm. It is stated once,
/// where it belongs (pre-work and active monitoring), never scattered on every
/// screen (directive §12).
class InfoNote extends StatelessWidget {
  const InfoNote({
    required this.text,
    this.icon = Icons.info_outline,
    super.key,
  });

  /// The passive-badge reminder, reused verbatim so the wording never drifts.
  const InfoNote.notAnAlarm({super.key})
    : text =
          'DoseBand does not provide real-time H₂S alarms. Keep following site '
          'gas detection and safety procedures.',
      icon = Icons.info_outline;

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.base),
      decoration: BoxDecoration(
        color: c.surfaceSunken,
        border: Border(
          left: BorderSide(
            color: c.measurementAccent,
            width: Borders.statusRule,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c.measurementAccent),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              text,
              style: context.type.body.copyWith(color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
