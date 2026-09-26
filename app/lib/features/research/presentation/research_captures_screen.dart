import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../application/research_providers.dart';
import '../domain/ordinal_comparison.dart';

/// Saved research captures, with export and the X0–X3 comparison.
///
/// Labelled **Research capture export** throughout, never a report: nothing
/// here is an occupational record and nothing here has regulatory standing.
/// §15.
class ResearchCapturesScreen extends ConsumerStatefulWidget {
  const ResearchCapturesScreen({super.key});

  @override
  ConsumerState<ResearchCapturesScreen> createState() =>
      _ResearchCapturesScreenState();
}

class _ResearchCapturesScreenState
    extends ConsumerState<ResearchCapturesScreen> {
  late Future<List<Map<String, Object?>>> _records;

  @override
  void initState() {
    super.initState();
    _records = ref.read(captureArchiveProvider).records();
  }

  Future<void> _shareOne(String captureId) async {
    final archive = ref.read(captureArchiveProvider);
    final dir = await archive.directoryFor(captureId);
    final files = <XFile>[
      for (final f in dir.listSync().whereType<File>()) XFile(f.path),
    ];
    await SharePlus.instance.share(
      ShareParams(
        files: files,
        subject: 'DoseBand research capture $captureId',
        text:
            'Research capture export — not an occupational exposure report. '
            'No H₂S calibration exists; this contains optical data only.',
      ),
    );
  }

  Future<void> _shareManifest() async {
    final file = await ref.read(captureArchiveProvider).writeManifest();
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path)],
        subject: 'DoseBand research capture manifest',
        text:
            'Research capture export — every record in this session, '
            'without images. Not an occupational exposure report.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Semantics(
            header: true,
            child: const Text('Research captures'),
          ),
          actions: <Widget>[
            IconButton(
              tooltip: 'Export session manifest',
              icon: const Icon(Icons.ios_share),
              onPressed: _shareManifest,
            ),
          ],
          bottom: const TabBar(
            tabs: <Tab>[
              Tab(text: 'Captures'),
              Tab(text: 'Compare X0–X3'),
            ],
          ),
        ),
        body: FutureBuilder<List<Map<String, Object?>>>(
          future: _records,
          builder: (context, snapshot) {
            final records = snapshot.data;
            if (records == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return TabBarView(
              children: <Widget>[
                _CaptureList(records: records, onShare: _shareOne),
                _Comparison(records: records),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CaptureList extends StatelessWidget {
  const _CaptureList({required this.records, required this.onShare});

  final List<Map<String, Object?>> records;
  final Future<void> Function(String) onShare;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No captures saved yet. Captures from the physical capture test '
          'appear here.',
        ),
      );
    }
    final newestFirst = records.reversed.toList();
    return ListView.separated(
      itemCount: newestFirst.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = newestFirst[i];
        final id = r['capture_id'] as String? ?? '?';
        final specimen = r['specimen'] as Map<String, Object?>?;
        final conditions = r['conditions'] as Map<String, Object?>?;
        final outcome = r['outcome'] as String? ?? '?';
        final deliberate = conditions?['is_deliberate_failure'] == true;
        final code = r['refusal_code'] as String?;
        return ListTile(
          leading: Icon(
            outcome == 'observed'
                ? Icons.check_circle_outline
                : Icons.block_outlined,
          ),
          title: Text(
            '${specimen?['specimen_id'] ?? '?'}'
            '${specimen?['series_level'] == null ? '' : ' · ${specimen!['series_level']}'}',
          ),
          subtitle: Text(
            [
              outcome == 'observed' ? 'optics valid' : 'refused',
              ?code,
              if (deliberate) 'staged failure',
              conditions?['illumination_class'] ?? '',
            ].where((s) => '$s'.isNotEmpty).join(' · '),
          ),
          trailing: IconButton(
            tooltip: 'Share this capture',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => onShare(id),
          ),
        );
      },
    );
  }
}

class _Comparison extends StatelessWidget {
  const _Comparison({required this.records});

  final List<Map<String, Object?>> records;

  @override
  Widget build(BuildContext context) {
    final result = compareBySeriesLevel(records);
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          'Descriptive only. X0–X3 are an intended order, not known '
          'exposures, and no threshold for "distinguishable" has been '
          'established. Separation is the step between adjacent levels in '
          'units of their pooled spread. Refused captures and staged '
          'failures are excluded, never pooled.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Levels with data: ${result.levels.isEmpty ? 'none' : result.levels.join(', ')}'
          ' · excluded captures: ${result.excludedCaptures.length}',
          style: theme.textTheme.bodyMedium,
        ),
        const Divider(height: 24),
        if (result.features.isEmpty)
          const Text(
            'No observed captures with a series level yet. Set a series level '
            'on the capture form to compare specimens.',
          ),
        for (final f in result.features)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${f.feature} — ${f.direction.name}'
                  '${f.reversals.isEmpty ? '' : ' (against: ${f.reversals.join(', ')})'}',
                  style: theme.textTheme.titleSmall,
                ),
                for (var i = 0; i < f.groups.length; i++)
                  Text(
                    '  ${f.groups[i].level}: n=${f.groups[i].count}  '
                    'mean ${f.groups[i].mean.toStringAsFixed(4)}  '
                    'sd ${f.groups[i].standardDeviation?.toStringAsFixed(4) ?? '—'}'
                    '${i == 0 ? '' : '  sep ${separation(f.groups[i - 1], f.groups[i])?.toStringAsFixed(2) ?? '—'}'}',
                    style: mono,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
