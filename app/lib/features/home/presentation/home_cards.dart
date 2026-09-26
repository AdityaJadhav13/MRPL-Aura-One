import 'package:flutter/material.dart';

import '../../../core/components/corporate.dart';
import '../../../core/design/brand_assets.dart';
import '../../../core/design/corporate_colors.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/util/format.dart';
import '../../workflow/domain/enterprise_value.dart';
import '../../workflow/domain/work_context.dart';
import '../../workflow/domain/worker_identity.dart';
import '../domain/home_presentation.dart';

/// The value shown where DoseBand has nothing.
///
/// A missing field produces an empty **value**, never an empty screen. The
/// worker keeps the whole mental model of what a monitored period needs, and
/// can see at a glance which parts are still outstanding.
const String _notProvided = 'Not provided';

/// MRPL and DoseBand identity over the refinery photograph.
class HomeHero extends StatelessWidget {
  const HomeHero({super.key});

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    // No fixed height. The hero has to absorb three things that vary between
    // devices and settings: the status-bar inset, the text scale, and the
    // 20-point overlap of the identity card. A constant tuned on one screen
    // overflows on the next — which is exactly what happened here, because
    // the golden tests render with no safe-area inset and a real iPhone has
    // one. The Stack sizes to its unpositioned child instead.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 176),
      child: Stack(
        children: [
          // A solid neutral ground under the photograph, so white type still
          // lands on a dark field if the asset is missing or slow to decode.
          Positioned.fill(child: ColoredBox(color: Neutral.l20)),
          Positioned.fill(
            child: Image.asset(
              BrandAssets.refineryBackdrop,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              // Decoded at display size, not at the file's full resolution.
              cacheWidth: 1080,
            ),
          ),
          // A solid translucent scrim, not a gradient (APP-PRODUCT-01 §8,
          // §29), and neutral rather than dark green: the photograph provides
          // the context, and a green wash over it made Home read as a green
          // screen.
          Positioned.fill(child: ColoredBox(color: context.product.scrim)),
          SafeArea(
            bottom: false,
            child: Padding(
              // The bottom inset clears the identity card, which lifts 20
              // logical pixels into the hero. Without it the strapline is
              // sliced in half by a white corner.
              padding: const EdgeInsets.fromLTRB(
                Space.base,
                Space.xs,
                Space.base,
                Space.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Two identities on one line. They are given fixed shares
                  // rather than laid out greedily, so the longer organisation
                  // name cannot crowd the product name off the screen.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mangalore Refinery',
                              style: t.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                height: 1.15,
                              ),
                            ),
                            Text(
                              'and Petrochemicals Limited',
                              style: t.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.86),
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // The hero wordmark is Home's title, so it is
                            // what a screen reader should land on first.
                            Semantics(
                              header: true,
                              child: Text(
                                'DoseBand',
                                style: t.bodyStrong.copyWith(
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                            ),
                            Text(
                              'OCCUPATIONAL\nEXPOSURE MONITORING',
                              textAlign: TextAlign.right,
                              style: t.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 8.5,
                                letterSpacing: 0.7,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.base),
                  Container(
                    height: 3,
                    width: 40,
                    decoration: BoxDecoration(
                      color: corporate.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    'Safe People',
                    style: t.display.copyWith(
                      color: Colors.white,
                      fontSize: 20,
                      height: 1.15,
                    ),
                  ),
                  Text(
                    'Sustainable Operations',
                    style: t.body.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The worker card, overlapping the hero.
class WorkerIdentityCard extends StatelessWidget {
  const WorkerIdentityCard({
    required this.worker,
    required this.onOpenProfile,
    super.key,
  });

  /// Null before any work context exists — the card still renders, with the
  /// identity slots empty, so the dashboard keeps its shape.
  final WorkerIdentity? worker;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final w = worker;

    // The account affordance lives on the worker's own card rather than as a
    // floating icon in a bar — that is where people look for themselves, and
    // it keeps the header from reading like a default scaffold.
    return Semantics(
      label: 'Account and profile',
      button: true,
      child: InfoCard(
        onTap: onOpenProfile,
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: corporate.primaryMuted,
                borderRadius: BorderRadius.circular(CorporateRadii.md),
              ),
              child: Icon(
                Icons.engineering_outlined,
                size: 26,
                color: corporate.primary,
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    w?.displayName ?? 'No worker signed in',
                    style: t.bodyStrong.copyWith(color: corporate.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    w == null
                        ? _notProvided
                        : '${w.workerType.label} · ID ${w.workerId}',
                    style: t.caption.copyWith(color: corporate.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (w?.contractorCompany case final company?)
                    Text(
                      company,
                      style: t.caption.copyWith(color: corporate.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: Space.sm),
            const _ConnectivityBadge(),
          ],
        ),
      ),
    );
  }
}

/// The app's true connectivity state.
///
/// Not "Online". DoseBand has no backend: there is nothing to be online *to*.
/// Saying so would be the easiest fake on the screen and the one a reviewer is
/// most likely to take at face value, since every app has a connectivity dot.
class _ConnectivityBadge extends StatelessWidget {
  const _ConnectivityBadge();

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Semantics(
      label:
          'Records are stored on this device. No backend is connected, so '
          'nothing is synchronised.',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.smartphone_outlined,
                size: 12,
                color: corporate.textSecondary,
              ),
              const SizedBox(width: Space.xs),
              Text(
                'Local',
                style: t.caption.copyWith(
                  color: corporate.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Text(
            'Not synced',
            style: t.caption.copyWith(
              color: corporate.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

/// Today's shift — two columns where the width allows.
class TodaysShiftCard extends StatelessWidget {
  const TodaysShiftCard({
    required this.context_,
    required this.now,
    required this.onViewDetails,
    super.key,
  });

  /// Passed in, never read from the clock here. A widget that reads
  /// `DateTime.now()` is not a function of its inputs, and cannot be rendered
  /// reproducibly in a golden. See `clockProvider`.
  final DateTime now;

  final WorkContext? context_;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final c = context_;

    return _SectionCard(
      title: "Today's shift",
      actionLabel: 'View details',
      onAction: onViewDetails,
      child: _FieldGrid(
        fields: [
          ('Site', c?.site.name ?? _notProvided, false),
          ('Department', c?.department.name ?? _notProvided, false),
          ('Shift', c?.shift.name ?? _notProvided, false),
          ('Work area', c?.workArea.name ?? 'Not selected', false),
          (
            'Gate pass',
            // Masked. A gate pass is a credential reference; showing it whole
            // on a screen that is read over shoulders buys nothing.
            c?.worker.gatePass == null
                ? 'Not provided'
                : _mask(c!.worker.gatePass!.value),
            true,
          ),
          ('Date', Fmt.date(now), true),
        ],
      ),
    );
  }

  static String _mask(String value) {
    if (value.length <= 4) return value;
    return '•••• ${value.substring(value.length - 4)}';
  }
}

/// Work context — the external references this period is attached to.
class WorkContextCard extends StatelessWidget {
  const WorkContextCard({
    required this.context_,
    required this.onViewAll,
    super.key,
  });

  final WorkContext? context_;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final c = context_;

    return _SectionCard(
      title: 'Work context',
      actionLabel: 'View all',
      onAction: onViewAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ContextRow(
            label: 'PTW',
            value: c?.permit.reference.value ?? _notProvided,
            source: c?.permit.reference.source,
            mono: true,
          ),
          _ContextRow(
            label: 'JSA',
            value: c == null ? _notProvided : 'Referenced',
            source: c?.jsa.reference.source,
          ),
          _ContextRow(
            label: 'Toolbox talk',
            // "Acknowledged", never "Completed" or "Verified": a tap on a
            // phone is not evidence that a conversation happened.
            value: c == null ? _notProvided : 'Acknowledged',
            source: c?.toolboxTalk.source,
          ),
          _ContextRow(
            label: 'Supervisor',
            value: c?.job.supervisor ?? _notProvided,
          ),
          if (c != null) ...[
            const SizedBox(height: 2),
            Text(
              'Recorded by the worker · not checked',
              style: t.caption.copyWith(
                color: corporate.textSecondary,
                fontSize: 10.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContextRow extends StatelessWidget {
  const _ContextRow({
    required this.label,
    required this.value,
    this.source,
    this.mono = false,
  });

  final String label;
  final String value;
  final EnterpriseDataSource? source;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: t.caption.copyWith(color: corporate.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: mono
                  ? t.readoutSmall.copyWith(color: corporate.textPrimary)
                  : t.body.copyWith(color: corporate.textPrimary),
            ),
          ),
          if (source != null) ...[
            const SizedBox(width: Space.sm),
            _SourceTag(source: source!),
          ],
        ],
      ),
    );
  }
}

class _SourceTag extends StatelessWidget {
  const _SourceTag({required this.source});

  final EnterpriseDataSource source;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: corporate.surfaceMuted,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: corporate.border),
      ),
      child: Text(
        source.label.toUpperCase(),
        style: t.caption.copyWith(
          color: corporate.textSecondary,
          fontSize: 9,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The main operational card.
///
/// ## Green here is identity, not a verdict
///
/// This card is MRPL green because it is the product's primary surface, not
/// because anything is safe. A valid reading means the instrument trusts the
/// measurement; it says nothing about the exposure. The card therefore never
/// carries a word like "safe", "normal" or "clear".
class MonitoringStatusCard extends StatelessWidget {
  const MonitoringStatusCard({
    required this.presentation,
    required this.badgeId,
    required this.startedAt,
    required this.coverage,
    super.key,
  });

  final HomePresentation presentation;
  final String? badgeId;
  final DateTime? startedAt;

  /// Null means the window cannot be established. It renders as the refusal
  /// placeholder and is never shown as `0`.
  final Duration? coverage;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final active = presentation.isMonitoring;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.base),
      decoration: BoxDecoration(
        // One solid brand fill, no gradient (APP-PRODUCT-01 §8). Home is
        // rebuilt in P3; until then this card keeps its role and loses only
        // the gradient.
        color: corporate.primaryDeep,
        borderRadius: BorderRadius.circular(CorporateRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(CorporateRadii.sm),
                ),
                child: Icon(
                  active ? Icons.sensors : Icons.badge_outlined,
                  size: 19,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  presentation.monitoringTitle.toUpperCase(),
                  style: t.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (active)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: corporate.accent,
                    borderRadius: BorderRadius.circular(CorporateRadii.sm),
                  ),
                  child: Text(
                    'ACTIVE',
                    style: t.caption.copyWith(
                      color: Colors.white,
                      fontSize: 9.5,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.base),
          LayoutBuilder(
            builder: (context, constraints) {
              final elapsed = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Always a duration or `- - -`. Earlier this rendered the
                  // state sentence here, and "Not started" wrapped to two
                  // lines at 26pt and was clipped by the card. The slot is
                  // for a measured quantity; the words belong below.
                  // Scaled down to fit rather than clipped. "3 h 42 min"
                  // truncating to "3 h 42" is not a cosmetic problem: it
                  // silently changes a duration, and a duration is part of
                  // the measurement.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      Fmt.duration(coverage),
                      maxLines: 1,
                      style: t.readoutLarge.copyWith(
                        color: Colors.white,
                        fontSize: 26,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    startedAt == null
                        ? presentation.monitoringState
                        : 'Started ${Fmt.clock(startedAt!)}',
                    style: t.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              );

              final badge = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DoseBand',
                    style: t.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    badgeId ?? 'Not assigned',
                    style: t.readoutSmall.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    presentation.monitoringState,
                    style: t.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              );

              // Side by side where there is room; stacked when text scaling
              // makes two columns collide.
              if (constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    elapsed,
                    const SizedBox(height: Space.md),
                    badge,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: elapsed),
                  Container(
                    width: 1,
                    height: 46,
                    color: Colors.white.withValues(alpha: 0.22),
                    margin: const EdgeInsets.symmetric(horizontal: Space.base),
                  ),
                  Expanded(child: badge),
                ],
              );
            },
          ),
          if (coverage == null && startedAt != null) ...[
            const SizedBox(height: Space.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_outlined,
                  size: 15,
                  color: Colors.white,
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    'The device clock moved while monitoring, so the duration '
                    'cannot be established.',
                    style: t.caption.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The narrow line under the primary action.
class DosimetryStatusStrip extends StatelessWidget {
  const DosimetryStatusStrip({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.sm,
      ),
      decoration: BoxDecoration(
        color: corporate.surfaceMuted,
        borderRadius: BorderRadius.circular(CorporateRadii.md),
        border: Border.all(color: corporate.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 15, color: corporate.textSecondary),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              message,
              style: t.caption.copyWith(color: corporate.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// The four quick actions.
class QuickActions extends StatelessWidget {
  const QuickActions({required this.onTap, super.key});

  final void Function(String route) onTap;

  static const _actions = <(IconData, String, String, String)>[
    (Icons.assignment_outlined, 'Work context', 'PTW / JSA', '/work-context'),
    (Icons.health_and_safety_outlined, 'Safety', 'H₂S info', '/safety/h2s'),
    (Icons.receipt_long_outlined, 'History', 'My records', '/history'),
    (
      Icons.emergency_outlined,
      'Emergency',
      'Site procedures',
      '/safety/emergency',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 4 : 2;
        const spacing = Space.sm;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final action in _actions)
              SizedBox(
                width: width,
                child: _QuickActionCard(
                  icon: action.$1,
                  title: action.$2,
                  subtitle: action.$3,
                  // Emergency carries the accent, not red: red is destructive
                  // in this system, and this is a route to information rather
                  // than an alarm.
                  emphasis: action.$4 == '/safety/emergency',
                  onTap: () => onTap(action.$4),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.emphasis = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;
    final tint = emphasis ? corporate.accent : corporate.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CorporateRadii.lg),
        child: Container(
          constraints: const BoxConstraints(minHeight: 84),
          padding: const EdgeInsets.all(Space.md),
          decoration: BoxDecoration(
            color: corporate.surfaceElevated,
            borderRadius: BorderRadius.circular(CorporateRadii.lg),
            border: Border.all(color: corporate.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 21, color: tint),
              const SizedBox(height: Space.sm),
              Text(
                title,
                style: t.bodyStrong.copyWith(
                  color: corporate.textPrimary,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: t.caption.copyWith(
                  color: corporate.textSecondary,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A titled card with an optional trailing action.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: t.caption.copyWith(
                    color: corporate.textSecondary,
                    letterSpacing: 0.9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null)
                InkWell(
                  onTap: onAction,
                  borderRadius: BorderRadius.circular(CorporateRadii.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.xs,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          actionLabel!,
                          style: t.caption.copyWith(color: corporate.primary),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 15,
                          color: corporate.primary,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.sm),
          child,
        ],
      ),
    );
  }
}

/// Label/value pairs in two columns where the width allows.
class _FieldGrid extends StatelessWidget {
  const _FieldGrid({required this.fields});

  /// (label, value, mono)
  final List<(String, String, bool)> fields;

  @override
  Widget build(BuildContext context) {
    final corporate = context.corporate;
    final t = context.type;

    return LayoutBuilder(
      builder: (context, constraints) {
        // One column once text scaling makes two unreadable.
        final columns =
            constraints.maxWidth < 280 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.4
            ? 1
            : 2;
        const spacing = Space.md;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: Space.sm,
          children: [
            for (final field in fields)
              SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.$1,
                      style: t.caption.copyWith(
                        color: corporate.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      field.$2,
                      style: field.$3
                          ? t.readoutSmall.copyWith(
                              color: corporate.textPrimary,
                            )
                          : t.body.copyWith(
                              color: corporate.textPrimary,
                              fontSize: 13.5,
                            ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
