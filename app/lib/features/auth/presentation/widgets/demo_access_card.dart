import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/corporate_colors.dart';
import '../../../../core/design/theme.dart';
import '../../../../core/design/tokens.dart';
import '../../data/demo_account.dart';

/// The published demo credentials, shown on the sign-in screen.
///
/// Anyone evaluating this prototype should be able to get in without being
/// told the password out of band. Hiding it would not make the prototype more
/// secure — there is nothing behind the form — it would only make the product
/// harder to review.
///
/// The card is styled as an aside rather than as part of the form: muted
/// surface, dashed emphasis on the word DEMO, and never the corporate green
/// used for real actions. It must read as scaffolding that will be removed,
/// not as a feature.
class DemoAccessCard extends StatelessWidget {
  const DemoAccessCard({required this.onUseCredentials, super.key});

  final VoidCallback onUseCredentials;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Container(
      padding: const EdgeInsets.all(Space.base),
      decoration: BoxDecoration(
        color: corporate.surfaceMuted,
        borderRadius: BorderRadius.circular(CorporateRadii.md),
        border: Border.all(color: corporate.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.science_outlined,
                size: 15,
                color: corporate.textSecondary,
              ),
              const SizedBox(width: Space.xs),
              Text(
                'DEMO ACCESS',
                style: t.caption.copyWith(
                  color: corporate.textSecondary,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(
            'This prototype is not connected to any MRPL system. These details '
            'are published so the flow can be reviewed.',
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
          const SizedBox(height: Space.base),
          _Credential(label: 'Worker ID', value: DemoAccount.workerId),
          const SizedBox(height: Space.sm),
          _Credential(label: 'Password', value: DemoAccount.password),
          const SizedBox(height: Space.base),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onUseCredentials,
              icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
              label: const Text('Use demo credentials'),
              style: OutlinedButton.styleFrom(
                foregroundColor: corporate.primary,
                side: BorderSide(color: corporate.border),
                minimumSize: const Size.fromHeight(kMinTouchTarget),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(CorporateRadii.md),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Credential extends StatelessWidget {
  const _Credential({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: t.caption.copyWith(color: corporate.textSecondary),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            // Monospace: this is a value to be transcribed exactly, which is
            // the same reason badge and record identifiers use it.
            style: t.readoutSmall.copyWith(color: corporate.textPrimary),
          ),
        ),
        IconButton(
          tooltip: 'Copy $label',
          visualDensity: VisualDensity.compact,
          icon: Icon(
            Icons.copy_outlined,
            size: 16,
            color: corporate.textSecondary,
          ),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text('$label copied'),
                ),
              );
          },
        ),
      ],
    );
  }
}

/// Shown when the form was complete but the values were not the demo account.
///
/// Deliberately names no organisation. MRPL was never queried, so "your MRPL
/// account is invalid" would be an invention — and the one place a user is
/// most likely to believe a claim about identity is the screen that just
/// refused them.
class SignInRejectionNotice extends StatelessWidget {
  const SignInRejectionNotice({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final c = context.colours;
    final t = context.type;

    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: corporate.surfaceMuted,
        borderRadius: BorderRadius.circular(CorporateRadii.md),
        border: Border.all(color: c.statusDestructive),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: c.statusDestructive),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              message,
              style: t.body.copyWith(color: corporate.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// A bottom sheet explaining that something is not connected.
///
/// Used by Forgot password and Gate Pass QR. Both are real controls in the
/// approved design and both lead nowhere today, so they say exactly that
/// rather than pretending an email was sent or a pass was read.
Future<void> showNotConnectedSheet(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  String? integration,
}) {
  final corporate = context.corporate;
  final t = context.type;

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: corporate.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(CorporateRadii.xl),
      ),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22, color: corporate.primary),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    title,
                    style: t.heading.copyWith(color: corporate.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            Text(
              message,
              style: t.body.copyWith(color: corporate.textSecondary),
            ),
            if (integration != null) ...[
              const SizedBox(height: Space.base),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.sm,
                  vertical: Space.xs,
                ),
                decoration: BoxDecoration(
                  color: corporate.surfaceMuted,
                  borderRadius: BorderRadius.circular(CorporateRadii.sm),
                  border: Border.all(color: corporate.border),
                ),
                child: Text(
                  '$integration · NOT CONNECTED',
                  style: t.caption.copyWith(
                    color: corporate.textSecondary,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
            const SizedBox(height: Space.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: corporate.primary,
                  foregroundColor: corporate.textOnPrimary,
                  minimumSize: const Size.fromHeight(kMinTouchTarget),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(CorporateRadii.md),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
