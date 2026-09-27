import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/components/buttons.dart';
import '../../../core/components/product_page.dart';
import '../../../core/components/product_status.dart';
import '../../../core/components/workspace_components.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/time/clock.dart';
import '../../auth/application/auth_controller.dart';
import '../../operations/application/hse_service.dart';
import '../../operations/application/operations_providers.dart';
import '../../operations/application/operations_repository.dart';
import '../../operations/domain/audit.dart';
import '../domain/register_export.dart';

/// The reports HSE can produce from real records (PRODUCT BUILD v1 §60).
enum HseReport {
  register(
    'Occupational exposure register',
    'Identified and restricted. Every record in scope, with its state.',
  ),
  exceptions(
    'Exception and review report',
    'Operational exceptions in scope over the last 30 days.',
  ),
  incomplete(
    'Incomplete monitoring report',
    'Periods interrupted or closed without a final read.',
  ),
  auditPackage(
    'Audit package',
    'Manifest, records, reviews and audit events, as JSON. Unsigned.',
  );

  const HseReport(this.title, this.description);

  final String title;
  final String description;
}

/// Reports: previews built from the scope-checked HSE view, exported as CSV
/// or JSON by copying or saving on this device. PDF is not implemented and is
/// not offered as though it were (§151).
class HseReportsScreen extends ConsumerStatefulWidget {
  const HseReportsScreen({super.key});

  @override
  ConsumerState<HseReportsScreen> createState() => _HseReportsScreenState();
}

class _HseReportsScreenState extends ConsumerState<HseReportsScreen> {
  HseReport _report = HseReport.register;
  ReportProfile _profile = ReportProfile.internalHse;

  String _build(HseView v, DateTime now) {
    final since = now.subtract(const Duration(days: 30));
    return switch (_report) {
      HseReport.register => RegisterExport.csv(
        RegisterExport.register(v.register()),
      ),
      HseReport.exceptions => RegisterExport.csv(
        RegisterExport.exceptions(v.exceptions(now), v.nameOf),
      ),
      HseReport.incomplete => RegisterExport.csv(
        RegisterExport.incomplete(v.incompleteSessions(since), v.nameOf),
      ),
      HseReport.auditPackage => () {
        final rows = v.register();
        final ids = {
          for (final r in rows) ...[r.record.id, r.record.badge.badgeId],
          for (final r in rows)
            if (r.record.sessionId != null) r.record.sessionId!,
        };
        return RegisterExport.auditPackage(
          profile: _profile,
          generatedAt: now,
          generatedBy: v.officer.personId,
          rows: rows,
          extra: {
            'reviews': [
              for (final r in rows)
                if (r.review != null)
                  {
                    'record_id': r.record.id,
                    'state': r.review!.state.name,
                    'disposition': r.review!.disposition?.name,
                    'reviewer_id': r.review!.reviewerId,
                  },
            ],
            'audit_events': [
              for (final e in v.auditFor(ids))
                {
                  'at': e.at.toUtc().toIso8601String(),
                  'action': e.action.name,
                  'actor_role': e.actorRole.name,
                  'subject': '${e.subjectType}:${e.subjectId}',
                },
            ],
          },
        );
      }(),
    };
  }

  String get _extension => _report == HseReport.auditPackage ? 'json' : 'csv';

  Future<void> _audit(String what) async {
    final actor = ref.read(currentActorProvider);
    if (actor == null) return;
    final ids = ref.read(idGeneratorProvider);
    final now = ref.read(clockProvider);
    await ref
        .read(operationsProvider.notifier)
        .transact(
          (s) => (
            next: s.appendAudit(
              AuditEvent(
                eventId: ids.next('AUD'),
                at: now(),
                actorId: actor.personId,
                actorRole: actor.role,
                action: AuditAction.exportRequested,
                subjectType: 'report',
                subjectId: _report.name,
                detail: what,
              ),
            ),
            result: null,
          ),
        );
  }

  Future<void> _copy(String content) async {
    await Clipboard.setData(ClipboardData(text: content));
    await _audit('Copied as ${_extension.toUpperCase()}');
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${_report.title} copied.')));
    }
  }

  Future<void> _save(String content, DateTime now) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final stamp = now.toIso8601String().replaceAll(':', '-').split('.').first;
      final file = File(
        '${dir.path}${Platform.pathSeparator}doseband-${_report.name}-$stamp.$_extension',
      );
      await file.writeAsString(content, flush: true);
      await _audit('Saved to ${file.path}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved in the app’s documents: ${file.path}')),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider)();
    return ProductPage(
      title: 'Reports',
      showBack: false,
      children: [
        OpsView(
          value: ref.watch(hseViewProvider),
          builder: (context, v) {
            final content = _build(v, now);
            final lines = content.split('\n');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in HseReport.values) ...[
                  ActionCard(
                    icon: r == _report
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    title: r.title,
                    message: r.description,
                    onTap: () => setState(() => _report = r),
                  ),
                  const SizedBox(height: Space.sm),
                ],
                const SizedBox(height: Space.sm),
                PageSection(
                  title: 'Layout profile',
                  children: [
                    ChoiceChips<ReportProfile>(
                      options: ReportProfile.values,
                      selected: _profile,
                      labelOf: (p) => p.label,
                      onSelected: (p) => setState(() => _profile = p),
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      _profile.caveat,
                      style: context.type.caption.copyWith(
                        color: context.product.textSecondary,
                      ),
                    ),
                  ],
                ),
                PageSection(
                  title: 'Preview · ${_report.title}',
                  children: [
                    SectionCard(
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SelectableText(
                            lines.take(40).join('\n') +
                                (lines.length > 40
                                    ? '\n… ${lines.length - 40} more lines'
                                    : ''),
                            style: context.type.readoutSmall.copyWith(
                              color: context.product.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.sm),
                    DoseBandButton.primary(
                      label: 'Copy ${_extension.toUpperCase()}',
                      icon: Icons.copy,
                      onPressed: () => _copy(content),
                    ),
                    const SizedBox(height: Space.sm),
                    DoseBandButton.secondary(
                      label: 'Save to this device',
                      icon: Icons.save_alt,
                      onPressed: () => _save(content, now),
                    ),
                  ],
                ),
                const StatusBanner(
                  tone: StatusTone.info,
                  icon: Icons.picture_as_pdf_outlined,
                  title: 'PDF is not available in this build',
                  message:
                      'Reports export as CSV or JSON on this device. Nothing '
                      'is sent anywhere, nothing is signed, and nothing here is '
                      'an authoritative organisational report.',
                ),
                const SizedBox(height: Space.base),
                const DataOriginNote(
                  'Identified report: restricted to authorised HSE use. '
                  'Contains only records within your scope.',
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
