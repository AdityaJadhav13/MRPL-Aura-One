import 'package:flutter/material.dart';

import '../../core/components/adaptive_records.dart';
import '../../core/components/buttons.dart';
import '../../core/components/identity.dart';
import '../../core/components/product_feedback.dart';
import '../../core/components/product_fields.dart';
import '../../core/components/product_navigation.dart';
import '../../core/components/product_page.dart';
import '../../core/components/product_states.dart';
import '../../core/components/product_status.dart';
import '../../core/design/product_colors.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/domain/connectivity.dart';
import '../../core/domain/provenance.dart';

/// The design system v2 component catalog (APP-PRODUCT-01 §49).
///
/// Development builds only (registered under `/dev`). Every shared component
/// and state in one place, so a visual change is reviewed here once rather
/// than discovered on twenty screens. The foundation goldens render these same
/// sections, so the catalog and the regression images cannot drift apart.
///
/// Nothing here is data. The one sample name is from the approved
/// presentation team; the sample identifiers are obviously specimens; there
/// are no quantities.
class ComponentCatalogScreen extends StatefulWidget {
  const ComponentCatalogScreen({super.key});

  @override
  State<ComponentCatalogScreen> createState() => _ComponentCatalogScreenState();
}

class _ComponentCatalogScreenState extends State<ComponentCatalogScreen> {
  double _textScale = 1;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      minScaleFactor: _textScale,
      maxScaleFactor: _textScale,
      child: ProductPage(
        title: 'Component catalog',
        actions: [
          PopupMenuButton<double>(
            tooltip: 'Text size',
            initialValue: _textScale,
            onSelected: (v) => setState(() => _textScale = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 1.0, child: Text('Text 100%')),
              PopupMenuItem(value: 1.3, child: Text('Text 130%')),
              PopupMenuItem(value: 1.5, child: Text('Text 150%')),
              PopupMenuItem(value: 2.0, child: Text('Text 200%')),
            ],
            icon: const Icon(Icons.format_size),
          ),
        ],
        children: const [
          CatalogPalette(),
          CatalogTypography(),
          CatalogSpacingAndRadii(),
          CatalogButtons(),
          CatalogInputs(),
          CatalogCards(),
          CatalogStatuses(),
          CatalogStates(),
          CatalogIdentity(),
          CatalogNavigation(),
          CatalogRecords(),
          CatalogFeedback(),
        ],
      ),
    );
  }
}

class CatalogPalette extends StatelessWidget {
  const CatalogPalette({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final swatches = <(String, Color, String)>[
      ('brandPrimary', p.brandPrimary, '#527823'),
      ('brandPrimaryPressed', p.brandPrimaryPressed, '#416318'),
      ('brandPrimaryContainer', p.brandPrimaryContainer, '#EAF0E0'),
      ('brandMark (logo)', p.brandMark, '#5C822D'),
      ('brandSecondary', p.brandSecondary, '#D96E0C'),
      ('surfacePage / Card', p.surfacePage, '#FFFFFF'),
      ('surfaceSecondary', p.surfaceSecondary, '#F3F3F3'),
      ('borderSubtle', p.borderSubtle, '#E8E8E8'),
      ('borderInput', p.borderInput, '#8B8B8B'),
      ('textPrimary', p.textPrimary, '#242424'),
      ('textSecondary', p.textSecondary, '#636363'),
      ('instrumentAccent', p.instrumentAccent, '#0E6E7D'),
      ('simulationAccent', p.simulationAccent, '#B5179E'),
      ('warning', p.warning, '#8A5A00'),
      ('critical', p.critical, '#A02114'),
      ('info', p.info, '#4A5C6A'),
    ];
    return PageSection(
      title: 'Colour',
      children: [
        Text(
          'Brand is not status. There is no "safe" colour.',
          style: context.type.caption.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final (name, colour, hex) in swatches)
              _Swatch(name: name, colour: colour, hex: hex),
          ],
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.name, required this.colour, required this.hex});

  final String name;
  final Color colour;
  final String hex;

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final t = context.type;
    return SizedBox(
      width: 172,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colour,
              borderRadius: BorderRadius.circular(Radii.sm),
              border: Border.all(color: p.borderSubtle),
            ),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: t.caption.copyWith(color: p.textPrimary)),
                Text(
                  hex,
                  style: t.readoutSmall.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CatalogTypography extends StatelessWidget {
  const CatalogTypography({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final t = context.type;
    Widget line(String role, TextStyle style, String sample) => Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(role, style: t.caption.copyWith(color: p.textSecondary)),
          Text(sample, style: style.copyWith(color: p.textPrimary)),
        ],
      ),
    );
    return PageSection(
      title: 'Typography',
      children: [
        line('Display · 28/34', t.display, 'Monitoring period'),
        line('Heading · 20/28', t.heading, 'Scan your DoseBand'),
        line('Body strong · 16/24', t.bodyStrong, 'DoseBand ready to use'),
        line('Body · 16/24', t.body, 'Hold the phone steady over the band.'),
        line('Label · 14/20', t.label, 'Scan new DoseBand'),
        line('Caption · 13/18', t.caption, 'Saved on this device'),
        line('Readout body · mono', t.readoutBody, 'DB-SPECIMEN-0001'),
        line('Readout small · mono', t.readoutSmall, '2026-09-27 08:14'),
      ],
    );
  }
}

class CatalogSpacingAndRadii extends StatelessWidget {
  const CatalogSpacingAndRadii({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.product;
    final t = context.type;
    return PageSection(
      title: 'Spacing and radii',
      children: [
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            for (final s in const [
              Space.xs,
              Space.sm,
              Space.md,
              Space.base,
              Space.lg,
              Space.xl,
              Space.xxl,
            ])
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: s,
                    height: s,
                    color: p.brandPrimaryContainer,
                  ),
                  Text(
                    s.toStringAsFixed(0),
                    style: t.readoutSmall.copyWith(color: p.textSecondary),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: Space.md),
        Wrap(
          spacing: Space.md,
          runSpacing: Space.sm,
          children: [
            for (final (name, r) in const [
              ('measurement 0', Radii.measurement),
              ('control 4', Radii.control),
              ('sm 8', Radii.sm),
              ('md 12', Radii.md),
              ('lg 16', Radii.lg),
            ])
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 40,
                    decoration: BoxDecoration(
                      color: p.surfaceSecondary,
                      borderRadius: BorderRadius.circular(r),
                      border: Border.all(color: p.borderDefault),
                    ),
                  ),
                  Text(name, style: t.caption.copyWith(color: p.textSecondary)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class CatalogButtons extends StatelessWidget {
  const CatalogButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return PageSection(
      title: 'Buttons',
      children: [
        DoseBandButton.primary(
          label: 'Scan new DoseBand',
          icon: Icons.qr_code_scanner,
          onPressed: () {},
        ),
        const SizedBox(height: Gaps.control),
        DoseBandButton.secondary(label: 'View history', onPressed: () {}),
        const SizedBox(height: Gaps.control),
        const DoseBandButton.primary(
          label: 'Saving record',
          onPressed: null,
          loading: true,
        ),
        const SizedBox(height: Gaps.control),
        const DoseBandButton.primary(label: 'Disabled', onPressed: null),
        const SizedBox(height: Gaps.control),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            DoseBandButton.tertiary(label: 'View details', onPressed: () {}),
            DoseBandButton.destructive(
              label: 'Discard capture',
              onPressed: () {},
              expand: false,
            ),
            IconButton(
              tooltip: 'Help',
              onPressed: () {},
              icon: const Icon(Icons.help_outline),
            ),
          ],
        ),
      ],
    );
  }
}

class CatalogInputs extends StatelessWidget {
  const CatalogInputs({super.key});

  @override
  Widget build(BuildContext context) {
    return PageSection(
      title: 'Inputs',
      children: [
        const ProductTextField(
          label: 'DoseBand ID',
          hint: 'As printed on the band',
          helper: 'Type it only if the QR code will not scan.',
        ),
        const SizedBox(height: Gaps.control),
        const ProductTextField(
          label: 'DoseBand ID',
          error: 'This ID is not in the expected format. Check the band.',
        ),
        const SizedBox(height: Gaps.control),
        const ProductTextField(label: 'Permit reference', loading: true),
        const SizedBox(height: Gaps.control),
        const ProductTextField(label: 'Disabled field', enabled: false),
        const SizedBox(height: Gaps.control),
        ProductSearchField(label: 'Search workers', onChanged: (_) {}),
        const SizedBox(height: Gaps.control),
        ProductDropdownField<String>(
          label: 'Shift',
          options: const ['Morning', 'Afternoon', 'Night'],
          labelOf: (s) => s,
          value: 'Morning',
          onChanged: (_) {},
        ),
        const SizedBox(height: Gaps.control),
        const ReadOnlyField(
          label: 'Employee ID',
          value: null,
          provenance: RecordProvenance.notConnected,
        ),
        const ReadOnlyField(
          label: 'DoseBand ID',
          value: 'DB-SPECIMEN-0001',
          mono: true,
          provenance: RecordProvenance.manualEntry,
        ),
      ],
    );
  }
}

class CatalogCards extends StatelessWidget {
  const CatalogCards({super.key});

  @override
  Widget build(BuildContext context) {
    return PageSection(
      title: 'Cards',
      children: [
        ActionCard(
          icon: Icons.qr_code_scanner,
          title: 'Scan new DoseBand',
          message: 'Start a monitoring period with a fresh band.',
          onTap: () {},
        ),
        const SizedBox(height: Gaps.control),
        const StatusBanner(
          tone: StatusTone.info,
          icon: Icons.link_off,
          title: 'Central server not connected',
          message: 'Records stay on this phone until a server is connected.',
        ),
        const SizedBox(height: Gaps.control),
        const StatusBanner(
          tone: StatusTone.attention,
          icon: Icons.replay,
          title: 'Image is blurred',
          message: 'Hold steady and retake the photo.',
        ),
        const SizedBox(height: Gaps.control),
        const StatusBanner(
          tone: StatusTone.critical,
          icon: Icons.error_outline,
          title: "Couldn't save this record",
          message:
              'The phone storage is full. Free some space and try again. '
              'Nothing was saved.',
        ),
      ],
    );
  }
}

class CatalogStatuses extends StatelessWidget {
  const CatalogStatuses({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final p = context.product;
    return PageSection(
      title: 'Status, provenance and sync',
      children: [
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final s in ProductStatus.values) ProductStatusChip(s),
          ],
        ),
        const SizedBox(height: Space.md),
        Text('Provenance', style: t.caption.copyWith(color: p.textSecondary)),
        const SizedBox(height: Space.xs),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final r in RecordProvenance.values) ProvenanceChip(r),
          ],
        ),
        const SizedBox(height: Space.md),
        Text('Sync', style: t.caption.copyWith(color: p.textSecondary)),
        const SizedBox(height: Space.xs),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [for (final s in SyncState.values) SyncStatusChip(s)],
        ),
      ],
    );
  }
}

class CatalogStates extends StatelessWidget {
  const CatalogStates({super.key});

  static const Map<StateKind, String> messages = {
    StateKind.loading: 'Reading your monitoring record.',
    StateKind.empty:
        'Your completed monitoring periods will appear here after your first '
        'final scan.',
    StateKind.noResults: 'No records match these filters. Clear a filter.',
    // What is true today. "Will sync when a connection is available" is the
    // P10 wording and must not appear until a sync queue exists (§42).
    StateKind.offline:
        'Your records stay on this phone. Nothing needs a connection yet.',
    StateKind.serverUnavailable:
        'The DoseBand server did not answer. Your phone is online. Try again '
        'shortly.',
    StateKind.permissionDenied: 'Your role does not include this information.',
    StateKind.notConnected:
        'No connection to the organisation system exists yet.',
    StateKind.notConfigured: 'Your organisation has not supplied this yet.',
    StateKind.unavailable: 'This cannot be shown right now.',
    StateKind.error: "Can't verify this DoseBand. Scan again.",
  };

  @override
  Widget build(BuildContext context) {
    return PageSection(
      title: 'States',
      children: [
        for (final k in StateKind.values) ...[
          StateView(
            kind: k,
            message: messages[k]!,
            compact: true,
            actionLabel:
                k == StateKind.error || k == StateKind.serverUnavailable
                ? 'Try again'
                : null,
            onAction: () {},
          ),
          const SizedBox(height: Gaps.control),
        ],
      ],
    );
  }
}

class CatalogIdentity extends StatelessWidget {
  const CatalogIdentity({super.key});

  @override
  Widget build(BuildContext context) {
    return PageSection(
      title: 'Identity',
      children: [
        const IdentityHeader(
          name: 'Aditya Jadhav',
          subtitle: 'Worker · presentation account',
          detail: 'No photograph supplied',
        ),
        const SizedBox(height: Space.md),
        const Wrap(
          spacing: Space.md,
          children: [
            IdentityAvatar(name: 'Aditya Jadhav', size: 32),
            IdentityAvatar(name: 'Aditya Jadhav', size: 48),
            IdentityAvatar(name: 'Aditya Jadhav', size: 64),
          ],
        ),
      ],
    );
  }
}

class CatalogNavigation extends StatefulWidget {
  const CatalogNavigation({super.key});

  @override
  State<CatalogNavigation> createState() => _CatalogNavigationState();
}

class _CatalogNavigationState extends State<CatalogNavigation> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return PageSection(
      title: 'Worker navigation',
      children: [
        // The real component, not a picture of it. MediaQuery strips the
        // system inset so the preview sits inside the page.
        MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: FloatingNavigationBar(
            destinations: WorkspaceDestinations.worker,
            selectedIndex: _index,
            onSelected: (i) => setState(() => _index = i),
          ),
        ),
      ],
    );
  }
}

class _SpecimenRecord {
  const _SpecimenRecord(this.id, this.worker, this.status, this.window);
  final String id;
  final String worker;
  final ProductStatus status;
  final String? window;
}

class CatalogRecords extends StatelessWidget {
  const CatalogRecords({super.key});

  static const _records = [
    _SpecimenRecord(
      'DB-SPECIMEN-0001',
      'Aditya Jadhav',
      ProductStatus.active,
      '08:00 →',
    ),
    _SpecimenRecord(
      'DB-SPECIMEN-0002',
      'Aditya Jadhav',
      ProductStatus.noReading,
      null,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return PageSection(
      title: 'Records (card on a phone, table when wide)',
      children: [
        AdaptiveRecordList<_SpecimenRecord>(
          records: _records,
          columns: [
            RecordColumn(
              label: 'DoseBand',
              cell: (r) => r.id,
              mono: true,
              primary: true,
              flex: 2,
            ),
            RecordColumn(label: 'Worker', cell: (r) => r.worker, flex: 2),
            RecordColumn(label: 'Window', cell: (r) => r.window, mono: true),
          ],
          trailing: (r) => ProductStatusChip(r.status),
        ),
      ],
    );
  }
}

class CatalogFeedback extends StatelessWidget {
  const CatalogFeedback({super.key});

  @override
  Widget build(BuildContext context) {
    return PageSection(
      title: 'Messages and dialogs',
      children: [
        DoseBandButton.secondary(
          label: 'Show a confirmation message',
          onPressed: () => showProductMessage(context, 'Profile photo removed'),
        ),
        const SizedBox(height: Gaps.control),
        DoseBandButton.secondary(
          label: 'Show a destructive confirmation',
          onPressed: () => showConfirmDialog(
            context,
            title: 'Discard this capture?',
            message:
                'The photo and its diagnostics will be deleted from this '
                'phone. This cannot be undone.',
            confirmLabel: 'Discard capture',
            cancelLabel: 'Keep capture',
            destructive: true,
          ),
        ),
      ],
    );
  }
}

/// Exposed for the foundation goldens: the colours a test can assert on.
ProductColors catalogColours(BuildContext context) => context.product;
