import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';

/// A person's avatar: their photograph when one exists, their initials
/// otherwise (APP-PRODUCT-01 §56).
///
/// No photograph is ever invented. Presentation accounts have none, so they
/// show initials. A photograph that fails to load falls back to initials too,
/// rather than to a broken-image glyph.
///
/// Decorative by default: the person's name is always printed beside it, and
/// announcing "avatar" first adds nothing for a screen-reader user.
class IdentityAvatar extends StatelessWidget {
  const IdentityAvatar({
    required this.name,
    this.photo,
    this.size = 48,
    super.key,
  });

  final String name;

  /// A bundled asset or a file the organisation supplied. Never a network
  /// placeholder face.
  final ImageProvider? photo;

  final double size;

  /// Up to two initials, from the first and last words of the name.
  static String initialsOf(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    final first = words.first.characters.first;
    if (words.length == 1) return first.toUpperCase();
    return (first + words.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final t = context.type;

    final initials = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.brandPrimaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        initialsOf(name),
        // Initials scale with the avatar, not with the text setting: the
        // circle is a fixed size and must not overflow its own text.
        textScaler: TextScaler.noScaling,
        style: t.bodyStrong.copyWith(
          color: p.onBrandContainer,
          fontSize: size * 0.38,
          height: 1,
        ),
      ),
    );

    final image = photo;
    return ExcludeSemantics(
      child: image == null
          ? initials
          : ClipOval(
              child: Image(
                image: image,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => initials,
                frameBuilder: (_, child, frame, wasSync) =>
                    wasSync || frame != null ? child : initials,
              ),
            ),
    );
  }
}

/// A person, as a row: avatar, name, and up to two lines of role/context.
class IdentityHeader extends StatelessWidget {
  const IdentityHeader({
    required this.name,
    this.subtitle,
    this.detail,
    this.photo,
    this.trailing,
    super.key,
  });

  final String name;
  final String? subtitle;
  final String? detail;
  final ImageProvider? photo;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final t = context.type;
    return Row(
      children: [
        IdentityAvatar(name: name, photo: photo),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: t.bodyStrong.copyWith(color: p.textPrimary)),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: t.caption.copyWith(color: p.textSecondary),
                ),
              if (detail != null)
                Text(
                  detail!,
                  style: t.caption.copyWith(color: p.textSecondary),
                ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: Space.sm), trailing!],
      ],
    );
  }
}
