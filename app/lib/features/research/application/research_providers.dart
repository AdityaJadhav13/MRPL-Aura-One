import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../capture/data/capture_archive.dart';
import '../domain/research_settings.dart';

/// The operator's current specimen and conditions.
///
/// Held in memory across captures on purpose: twenty photographs of one
/// specimen under one lamp should be twenty shutter presses, not twenty forms.
/// Not persisted — a research session that silently resumed yesterday's
/// specimen id after a restart would mislabel the first capture of the day.
final researchSettingsProvider =
    NotifierProvider<ResearchSettingsController, ResearchSettings>(
      ResearchSettingsController.new,
    );

class ResearchSettingsController extends Notifier<ResearchSettings> {
  @override
  ResearchSettings build() => const ResearchSettings(specimenId: '');

  void update(ResearchSettings settings) => state = settings;
}

/// Where research captures are archived. Overridden in tests.
final captureArchiveProvider = Provider<CaptureArchive>(
  (_) => CaptureArchive(),
);
