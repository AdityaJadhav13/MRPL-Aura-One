import 'package:flutter/material.dart';

import '../../../../core/design/theme.dart';
import '../../../../core/design/tokens.dart';
import 'mrpl_brandmark.dart';

/// The corporate identity block: brandmark, company name, tagline.
///
/// Shared by every authenticated-shell screen so the identity sits in exactly
/// the same place throughout the flow. A header that shifts between screens
/// reads as three different products.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({
    this.markSize = 46,
    this.showTagline = true,
    super.key,
  });

  final double markSize;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        MrplBrandmark(size: markSize),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Mangalore Refinery\nand Petrochemicals Limited',
                style: t.bodyStrong.copyWith(
                  color: corporate.primary,
                  height: 1.22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (showTagline) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  'Refining for a Brighter Tomorrow',
                  style: t.caption.copyWith(color: corporate.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The product lockup: DoseBand over its descriptor.
class DoseBandLockup extends StatelessWidget {
  const DoseBandLockup({this.onDark = false, this.fontSize = 34, super.key});

  final bool onDark;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final titleColour = onDark ? corporate.textOnPrimary : corporate.primary;
    final subtitleColour = onDark
        ? corporate.textOnPrimary.withValues(alpha: 0.82)
        : corporate.textSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'DoseBand',
          textAlign: TextAlign.center,
          style: t.display.copyWith(
            fontSize: fontSize,
            height: 1.05,
            fontWeight: FontWeight.w700,
            color: titleColour,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'OCCUPATIONAL EXPOSURE MONITORING',
          textAlign: TextAlign.center,
          style: t.caption.copyWith(
            color: subtitleColour,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
