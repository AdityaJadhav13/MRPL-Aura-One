import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/buttons.dart';
import '../../../core/components/product_fields.dart';
import '../../../core/components/product_page.dart';
import '../../../core/components/product_states.dart';
import '../../../core/components/product_status.dart';
import '../../../core/components/workspace_components.dart';
import '../../../core/domain/doseband.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/env/environment.dart';
import '../../../core/time/clock.dart';
import '../../../core/util/format.dart';
import '../../account/presentation/workspace_more_screen.dart';
import '../../auth/domain/auth_models.dart';
import '../../doseband/data/qr_codec.dart';
import '../../doseband/domain/doseband_qr.dart';
import '../../operations/application/admin_service.dart';
import '../../operations/application/operations_providers.dart';
import '../../operations/application/operations_repository.dart';
import '../../operations/application/worker_service.dart';
import '../../operations/domain/inventory.dart';
import '../../operations/presentation/ops_chips.dart';
import '../data/admin_demo_catalog.dart';

const _origin =
    'Directory and inventory from the operations records on this device. '
    'Administration here grants no access to exposure records.';

/// Administration overview (PRODUCT BUILD v1 §44).
class AdminOverviewScreen extends ConsumerWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final integrations = AdminDemoCatalog.integrations();
    return ProductPage(
      title: 'Administration',
      showBack: false,
      children: [
        OpsView(
          value: ref.watch(adminViewProvider),
          builder: (context, v) {
            final accounts = v.accounts();
            final totals = v.totals(now);
            final audit = v.audit(limit: 5);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CountGrid(
                  tiles: [
                    CountTile(
                      label: 'Accounts',
                      value: '${accounts.length}',
                      onTap: () => context.go('/admin/people'),
                    ),
                    CountTile(
                      label: 'Suspended',
                      value:
                          '${accounts.where((a) => !a.person.active).length}',
                    ),
                    CountTile(
                      label: 'DoseBands available',
                      value: '${totals[InventoryBucket.available] ?? 0}',
                      onTap: () => context.go('/admin/doseband'),
                    ),
                    CountTile(
                      label: 'DoseBands in use',
                      value: '${totals[InventoryBucket.inUse] ?? 0}',
                    ),
                    CountTile(
                      label: 'Integrations connected',
                      value: '0 of ${integrations.length}',
                      onTap: () => context.push('/admin/integrations'),
                    ),
                    CountTile(
                      label: 'Audit events',
                      value: '${v.auditEventCount}',
                      onTap: () => context.push('/admin/audit'),
                    ),
                  ],
                ),
                const SizedBox(height: Gaps.section),
                const StatusBanner(
                  tone: StatusTone.info,
                  icon: Icons.lock_outline,
                  title: 'No exposure-record access',
                  message:
                      'Administering the system does not include occupational '
                      'exposure records. They are for the worker, their '
                      'supervisor and HSE.',
                ),
                const SizedBox(height: Gaps.section),
                PageSection(
                  title: 'Recent activity',
                  trailing: DoseBandButton.tertiary(
                    label: 'All',
                    onPressed: () => context.push('/admin/audit'),
                  ),
                  children: [
                    RowList(children: [for (final r in audit) _AuditTile(r)]),
                  ],
                ),
                DataOriginNote(
                  '$_origin Dataset ${v.datasetVersion}, seeded '
                  '${Fmt.stamp(v.seededAt)}.',
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile(this.row);

  final AdminAuditRow row;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(row.action.label),
    subtitle: Text(
      [Fmt.stamp(row.at), row.actor, row.subject, ?row.detail].join(' · '),
    ),
  );
}

/// People: the account directory — identity and roles only (§44, §149).
class AdminPeopleScreen extends ConsumerStatefulWidget {
  const AdminPeopleScreen({super.key});

  @override
  ConsumerState<AdminPeopleScreen> createState() => _AdminPeopleScreenState();
}

class _AdminPeopleScreenState extends ConsumerState<AdminPeopleScreen> {
  String _query = '';
  AppRole? _role;

  @override
  Widget build(BuildContext context) {
    return ProductPage(
      title: 'People',
      showBack: false,
      children: [
        OpsView(
          value: ref.watch(adminViewProvider),
          builder: (context, v) {
            final rows = v.accounts(query: _query, role: _role);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProductSearchField(
                  label: 'Search accounts',
                  hint: 'Name, ID or designation',
                  onChanged: (q) => setState(() => _query = q),
                ),
                const SizedBox(height: Space.sm),
                ChoiceChips<AppRole?>(
                  options: const [null, ...AppRole.values],
                  selected: _role,
                  labelOf: (r) => r?.label ?? 'All roles',
                  onSelected: (r) => setState(() => _role = r),
                ),
                const SizedBox(height: Space.base),
                if (rows.isEmpty)
                  const StateView(
                    kind: StateKind.noResults,
                    message: 'No account matches.',
                  )
                else
                  RowList(
                    children: [
                      for (final a in rows)
                        PersonTile(
                          name: a.person.displayName,
                          detail:
                              '${a.person.personId} · '
                              '${a.person.roles.map((r) => r.label).join(', ')}',
                          status: a.person.active
                              ? null
                              : const ToneChip(
                                  label: 'Suspended',
                                  icon: Icons.block,
                                  tone: StatusTone.attention,
                                ),
                          onTap: () => context.push(
                            '/admin/people/${a.person.personId}',
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: Space.base),
                const DataOriginNote(
                  'Presentation accounts on this device. No organisation '
                  'directory is connected.',
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class AdminPersonScreen extends ConsumerWidget {
  const AdminPersonScreen({required this.personId, super.key});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProductPage(
      title: 'Account',
      children: [
        OpsView(
          value: ref.watch(adminViewProvider),
          builder: (context, v) {
            final a = v.accounts().where((x) => x.person.personId == personId);
            if (a.isEmpty) {
              return const StateView(
                kind: StateKind.empty,
                message: 'No account with this ID.',
              );
            }
            final row = a.first;
            final p = row.person;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionCard(
                  children: [
                    FactRow(label: 'Name', value: p.displayName),
                    FactRow(label: 'ID', value: p.personId, mono: true),
                    FactRow(label: 'Type', value: p.workerType.label),
                    if (p.contractorCompany != null)
                      FactRow(label: 'Company', value: p.contractorCompany!),
                    FactRow(
                      label: 'Department',
                      value: row.departmentName ?? p.departmentId,
                    ),
                    FactRow(label: 'Designation', value: p.designation),
                    FactRow(
                      label: 'Status',
                      value: p.active ? 'Active' : 'Suspended',
                    ),
                  ],
                ),
                const SizedBox(height: Gaps.section),
                PageSection(
                  title: 'Roles and scopes',
                  children: [
                    RowList(
                      children: [
                        for (final g in row.grants)
                          ListTile(
                            title: Text(g.role.label),
                            subtitle: Text(
                              '${g.scope.name} · ${_scopeTarget(v, g.targetId)}',
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      'Roles and scopes come from the directory. Editing them '
                      'needs the organisation directory, which is not '
                      'connected; this build shows them as recorded.',
                      style: context.type.caption.copyWith(
                        color: context.product.textSecondary,
                      ),
                    ),
                  ],
                ),
                DoseBandButton.secondary(
                  label: p.active ? 'Suspend account' : 'Restore account',
                  onPressed: () async {
                    try {
                      await ref
                          .read(adminCommandsProvider)
                          .setAccountActive(
                            personId: p.personId,
                            active: !p.active,
                          );
                    } on OperationRefused catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(e.reason)));
                      }
                    }
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  static String _scopeTarget(AdminView v, String id) {
    for (final t in v.teams) {
      if (t.teamId == id) return t.name;
    }
    return v.nameOf(id) ?? id;
  }
}

/// DoseBand inventory: formulation → lot → serial (§46).
class AdminDoseBandsScreen extends ConsumerWidget {
  const AdminDoseBandsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    return ProductPage(
      title: 'DoseBand inventory',
      showBack: false,
      children: [
        OpsView(
          value: ref.watch(adminViewProvider),
          builder: (context, v) {
            final lots = v.lots(now);
            final totals = v.totals(now);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CountGrid(
                  tiles: [
                    for (final b in InventoryBucket.values)
                      CountTile(label: b.label, value: '${totals[b] ?? 0}'),
                  ],
                ),
                const SizedBox(height: Space.xs),
                Text(
                  'Each DoseBand is counted once. The buckets add up to the '
                  'inventory.',
                  style: context.type.caption.copyWith(
                    color: context.product.textSecondary,
                  ),
                ),
                for (final f in v.formulations) ...[
                  const SizedBox(height: Gaps.section),
                  PageSection(
                    title: '${f.name} ${f.version}',
                    trailing: ToneChip(
                      label: f.validated ? 'Validated' : 'Not validated',
                      icon: Icons.science_outlined,
                      tone: StatusTone.neutral,
                    ),
                    children: [
                      RowList(
                        children: [
                          for (final l in lots.where(
                            (l) => l.lot.formulationId == f.formulationId,
                          ))
                            _LotTile(summary: l, now: now),
                        ],
                      ),
                    ],
                  ),
                ],
                const DataOriginNote(_origin),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LotTile extends StatelessWidget {
  const _LotTile({required this.summary, required this.now});

  final LotSummary summary;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = summary.lot;
    final expired = l.isExpiredOn(now);
    final t = context.type;
    final p = context.product;
    return InkWell(
      onTap: () => context.push('/admin/doseband/lot/${l.lotId}'),
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.lotId,
                    style: t.readoutSmall.copyWith(color: p.textPrimary),
                  ),
                ),
                Icon(Icons.chevron_right, color: p.textSecondary),
              ],
            ),
            Text(
              '${summary.total} DoseBands · geometry ${l.geometryVersion} · '
              'expires ${l.expiresOn == null ? 'not recorded' : Fmt.date(l.expiresOn!)}',
              style: t.caption.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: Space.xs),
            Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: [
                if (expired)
                  const ToneChip(
                    label: 'Lot expired',
                    icon: Icons.event_busy,
                    tone: StatusTone.attention,
                  ),
                if (!l.supportedConfiguration)
                  const ToneChip(
                    label: 'Configuration not supported',
                    icon: Icons.block,
                    tone: StatusTone.attention,
                  ),
                ToneChip(
                  label: l.calibrationPackageId == null
                      ? 'No calibration'
                      : 'Calibration ${l.calibrationPackageId}',
                  icon: Icons.tune,
                  tone: StatusTone.neutral,
                ),
                for (final e in summary.counts.entries)
                  ToneChip(
                    label: '${e.key.label}: ${e.value}',
                    icon: Icons.circle,
                    tone: StatusTone.neutral,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AdminLotScreen extends ConsumerStatefulWidget {
  const AdminLotScreen({required this.lotId, super.key});

  final String lotId;

  @override
  ConsumerState<AdminLotScreen> createState() => _AdminLotScreenState();
}

class _AdminLotScreenState extends ConsumerState<AdminLotScreen> {
  String _query = '';
  InventoryBucket? _bucket;

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider)();
    return ProductPage(
      title: 'Lot ${widget.lotId}',
      children: [
        OpsView(
          value: ref.watch(adminViewProvider),
          builder: (context, v) {
            final bands = v.bands(
              now,
              lotId: widget.lotId,
              query: _query,
              bucket: _bucket,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProductSearchField(
                  label: 'Search serials',
                  hint: 'DB-2609-0101',
                  onChanged: (q) => setState(() => _query = q),
                ),
                const SizedBox(height: Space.sm),
                ChoiceChips<InventoryBucket?>(
                  options: const [null, ...InventoryBucket.values],
                  selected: _bucket,
                  labelOf: (b) => b?.label ?? 'All',
                  onSelected: (b) => setState(() => _bucket = b),
                ),
                const SizedBox(height: Space.base),
                if (bands.isEmpty)
                  const StateView(
                    kind: StateKind.noResults,
                    message: 'No DoseBand matches.',
                  )
                else
                  RowList(
                    children: [
                      for (final b in bands)
                        ListTile(
                          minTileHeight: kMinTouchTarget,
                          title: Text(b.band.dosebandId),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: Space.xs),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: LifecycleChip(b.band.lifecycle),
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(
                            '/admin/doseband/band/${b.band.dosebandId}',
                          ),
                        ),
                    ],
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// One serialised band: its state, its label, and the inventory actions the
/// lifecycle allows. Never who holds it.
class AdminBandScreen extends ConsumerWidget {
  const AdminBandScreen({required this.dosebandId, super.key});

  final String dosebandId;

  static const _actions = [
    DoseBandLifecycle.damaged,
    DoseBandLifecycle.lost,
    DoseBandLifecycle.invalid,
    DoseBandLifecycle.expired,
    DoseBandLifecycle.disposed,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    return ProductPage(
      title: dosebandId,
      children: [
        OpsView(
          value: ref.watch(adminViewProvider),
          builder: (context, v) {
            final row = v
                .bands(now)
                .where((b) => b.band.dosebandId == dosebandId)
                .firstOrNull;
            if (row == null) {
              return const StateView(
                kind: StateKind.empty,
                message: 'No DoseBand with this serial.',
              );
            }
            final inUse = row.bucket == InventoryBucket.inUse;
            final allowed = inUse
                ? const <DoseBandLifecycle>[]
                : _actions
                      .where(
                        (a) => DoseBandLifecyclePolicy.allows(
                          row.band.lifecycle,
                          a,
                        ),
                      )
                      .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionCard(
                  children: [
                    FactRow(label: 'Serial', value: dosebandId, mono: true),
                    FactRow(
                      label: 'Lot',
                      value: row.band.lotId ?? '—',
                      mono: true,
                    ),
                    FactRow(
                      label: 'Lifecycle',
                      value: row.band.lifecycle.label,
                    ),
                    FactRow(label: 'Inventory', value: row.bucket.label),
                    FactRow(
                      label: 'Geometry',
                      value: row.band.geometryVersion ?? '—',
                      mono: true,
                    ),
                  ],
                ),
                const SizedBox(height: Gaps.section),
                PageSection(
                  title: 'QR label',
                  children: [
                    Center(child: QrLabel(dosebandId: dosebandId)),
                    const SizedBox(height: Space.xs),
                    Text(
                      'Label contract v${DoseBandQr.currentVersion}: '
                      '${DoseBandQr.encode(dosebandId)}. Identity only — no '
                      'signature, no lot data printed.',
                      style: context.type.caption.copyWith(
                        color: context.product.textSecondary,
                      ),
                    ),
                  ],
                ),
                PageSection(
                  title: 'Take out of service',
                  children: [
                    if (allowed.isEmpty)
                      Text(
                        !inUse && row.band.lifecycle.isTerminal
                            ? 'This DoseBand has left service.'
                            : 'Not while it is in use: its monitoring period '
                                  'has to end first.',
                        style: context.type.body.copyWith(
                          color: context.product.textPrimary,
                        ),
                      )
                    else
                      for (final a in allowed) ...[
                        DoseBandButton.secondary(
                          label: switch (a) {
                            DoseBandLifecycle.damaged => 'Mark as damaged',
                            DoseBandLifecycle.lost => 'Mark as lost',
                            DoseBandLifecycle.invalid => 'Mark as invalid',
                            DoseBandLifecycle.expired => 'Mark as expired',
                            _ => 'Mark as disposed',
                          },
                          onPressed: () => ref
                              .read(adminCommandsProvider)
                              .setBandCondition(dosebandId: dosebandId, to: a),
                        ),
                        const SizedBox(height: Space.sm),
                      ],
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// A printable QR label drawn from the module matrix — solid squares, no
/// image asset, no network.
class QrLabel extends StatelessWidget {
  const QrLabel({required this.dosebandId, this.size = 200, super.key});

  final String dosebandId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final modules = QrCodec.modules(DoseBandQr.encode(dosebandId));
    return Semantics(
      label: 'QR label for $dosebandId',
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(Space.md),
            child: CustomPaint(
              size: Size.square(size),
              painter: _QrPainter(modules),
            ),
          ),
          Text(
            dosebandId,
            style: context.type.readoutSmall.copyWith(
              color: context.product.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.modules);

  final List<List<bool>> modules;

  @override
  void paint(Canvas canvas, Size size) {
    final n = modules.length;
    final cell = size.width / n;
    final paint = Paint()..color = Colors.black;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        if (modules[y][x]) {
          canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter old) => old.modules != modules;
}

/// System: configuration and status, one hub (§44).
class AdminSystemScreen extends StatelessWidget {
  const AdminSystemScreen({super.key});

  static const _links = [
    MoreLink(
      icon: Icons.link_off,
      title: 'Integrations',
      message: 'Every enterprise integration and its true state',
      route: '/admin/integrations',
    ),
    MoreLink(
      icon: Icons.tune,
      title: 'Calibration packages',
      message: 'None validated. S1–S3 remain open.',
      route: '/admin/calibration',
    ),
    MoreLink(
      icon: Icons.grid_on,
      title: 'Badge geometry',
      message: 'Printed geometry versions the reader supports',
      route: '/admin/badges',
    ),
    MoreLink(
      icon: Icons.place_outlined,
      title: 'Sites, departments and work areas',
      message: 'Organisation structure used for work context',
      route: '/admin/sites',
    ),
    MoreLink(
      icon: Icons.inventory_outlined,
      title: 'Retention',
      message: 'Record-type retention profiles (not yet classified by MRPL)',
      route: '/admin/retention',
    ),
    MoreLink(
      icon: Icons.sync_disabled,
      title: 'Sync',
      message: 'No server connected; records stay on each device',
      route: '/admin/sync',
    ),
    MoreLink(
      icon: Icons.history,
      title: 'Audit log',
      message: 'Local, append-only; occupational actions withheld',
      route: '/admin/audit',
    ),
    MoreLink(
      icon: Icons.info_outline,
      title: 'Versions and system information',
      message: 'App, engine, geometry and build facts',
      route: '/admin/system/info',
    ),
  ];

  @override
  Widget build(BuildContext context) => ProductPage(
    title: 'System',
    showBack: false,
    children: [
      for (final l in _links) ...[
        ActionCard(
          icon: l.icon,
          title: l.title,
          message: l.message,
          onTap: () => context.push(l.route),
        ),
        const SizedBox(height: Space.sm),
      ],
    ],
  );
}

class AdminAuditScreen extends ConsumerWidget {
  const AdminAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ProductPage(
    title: 'Audit log',
    children: [
      OpsView(
        value: ref.watch(adminViewProvider),
        builder: (context, v) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Local audit log on this device. Append-only in this app; not '
              'tamper-proof, and not an enterprise audit service. For '
              'occupational actions the person is withheld.',
              style: context.type.caption.copyWith(
                color: context.product.textSecondary,
              ),
            ),
            const SizedBox(height: Space.sm),
            RowList(children: [for (final r in v.audit()) _AuditTile(r)]),
          ],
        ),
      ),
    ],
  );
}

class AdminMoreScreen extends StatelessWidget {
  const AdminMoreScreen({required this.config, super.key});

  final EnvironmentConfig config;

  @override
  Widget build(BuildContext context) => WorkspaceMoreScreen(
    config: config,
    links: [
      if (config.simulationAvailable)
        const MoreLink(
          icon: Icons.restart_alt,
          title: 'Presentation data',
          message: 'Reset the presentation dataset (development builds only)',
          route: '/admin/demo-data',
        ),
      // Engineering and research tooling (capture diagnostics, geometry,
      // research captures). Not a worker feature: it is reached only from
      // here, in development builds, never from Home, Profile or Settings.
      if (config.simulationAvailable)
        const MoreLink(
          icon: Icons.build_outlined,
          title: 'Developer and research tools',
          message: 'Engineering tooling (development builds only)',
          route: '/dev',
        ),
    ],
  );
}

/// Development builds only: what the presentation dataset holds, and a reset.
class PresentationDataScreen extends ConsumerWidget {
  const PresentationDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(operationsProvider);
    return ProductPage(
      title: 'Presentation data',
      children: [
        OpsView(
          value: snapshot,
          builder: (context, s) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StatusBanner(
                tone: StatusTone.info,
                icon: Icons.construction_outlined,
                title: 'Development build only',
                message:
                    'Sample organisational data for presentation. Not from '
                    'any MRPL system. Compiled out of production.',
              ),
              const SizedBox(height: Space.base),
              SectionCard(
                children: [
                  FactRow(
                    label: 'Dataset',
                    value: s.datasetVersion,
                    mono: true,
                  ),
                  FactRow(label: 'Seeded', value: Fmt.stamp(s.seededAt)),
                  FactRow(label: 'People', value: '${s.people.length}'),
                  FactRow(label: 'DoseBands', value: '${s.bands.length}'),
                  FactRow(
                    label: 'Monitoring periods',
                    value: '${s.sessions.length}',
                  ),
                  FactRow(
                    label: 'Measurement records',
                    value:
                        '${s.measurements.length} (produced on this device; none '
                        'are seeded)',
                  ),
                  FactRow(label: 'Audit events', value: '${s.audit.length}'),
                ],
              ),
              const SizedBox(height: Space.base),
              DoseBandButton.destructive(
                label: 'Reset presentation data',
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Reset presentation data?'),
                      content: const Text(
                        'Every assignment, monitoring period, record, review '
                        'and audit event on this device is discarded and the '
                        'dataset is seeded again. Captured photographs in the '
                        'research archive are kept.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(c).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(c).pop(true),
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await ref
                        .read(operationsProvider.notifier)
                        .resetPresentationData();
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
