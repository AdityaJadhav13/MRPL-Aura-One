import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import 'buttons.dart';
import 'step_scaffold.dart';

/// What kind of transient outcome a message reports (APP-PRODUCT-01 §53).
///
/// There is no `success` kind drawn in green. A confirmation says what was
/// done, in neutral ink; on a measurement surface a green toast reads as "all
/// clear", which DoseBand can never say.
enum MessageKind {
  /// Something the user asked for was done. Only after it actually was.
  confirmation(Icons.check),
  warning(Icons.warning_amber_rounded),
  failure(Icons.error_outline),
  offline(Icons.cloud_off_outlined);

  const MessageKind(this.icon);
  final IconData icon;
}

/// Shows a transient message.
///
/// **Only for transient outcomes.** A measurement result, a refusal or
/// anything the worker must act on is never a snack bar: it would disappear
/// before it was read (§53).
void showProductMessage(
  BuildContext context,
  String message, {
  MessageKind kind = MessageKind.confirmation,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final p = context.product;
  final t = context.type;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(kind.icon, size: 20, color: p.surfaceCard),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(
                message,
                style: t.body.copyWith(color: p.surfaceCard),
              ),
            ),
          ],
        ),
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction),
      ),
    );
}

/// Asks the user to confirm an action. Returns true only for an explicit yes.
///
/// When to use what (§52):
///
/// * **Dialog** — one yes/no question about one action. This function.
/// * **Bottom sheet** — a short choice among a few options, or a short
///   explanation the user can dismiss.
/// * **Full screen** — anything with more than one step or more than one
///   field. Worker-critical flows are always full screens, never a dialog.
///
/// The confirm label must name the action ("Discard capture"), never "OK";
/// the cancel label keeps the user where they were. A [destructive] action is
/// drawn in the destructive style and is not the default focus.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => StepRegisterScope(
      register: StepRegister.corporate,
      child: AlertDialog(
        title: Semantics(header: true, child: Text(title)),
        content: Text(message),
        actionsPadding: const EdgeInsets.fromLTRB(
          Space.base,
          0,
          Space.base,
          Space.base,
        ),
        actions: [
          // Stacked, full width: two labels of any length fit at any text
          // size, and each is a gloved-thumb target.
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (destructive)
                DoseBandButton.destructive(
                  label: confirmLabel,
                  onPressed: () => Navigator.of(context).pop(true),
                )
              else
                DoseBandButton.primary(
                  label: confirmLabel,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              const SizedBox(height: Space.sm),
              DoseBandButton.secondary(
                label: cancelLabel,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}
