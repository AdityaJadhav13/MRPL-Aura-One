import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:h2s_doseband/features/workflow/domain/work_context_validator.dart';
import 'package:h2s_doseband/features/workflow/presentation/widgets/work_context_summary.dart';

/// Wording is part of the safety boundary.
///
/// DoseBand measures cumulative exposure. It does not authorise work, issue or
/// check permits, run job safety analyses, hold toolbox talks, detect gas in
/// real time, or sound alarms. A worker who reads a DoseBand screen as saying
/// any of those things has been misled by the product, and no amount of correct
/// arithmetic behind the screen repairs that.
///
/// The phrases below are therefore treated as defects in the source, not as
/// copy choices. A test is the right place for this because wording is edited
/// by whoever is nearest, often in a hurry, usually to make a screen shorter.
void main() {
  /// Affirmative claims DoseBand is not entitled to make.
  ///
  /// Word boundaries matter. "site safety requirements" is legitimate and must
  /// not trip `site safe`; "does not authorise the work" is legitimate and must
  /// not trip `work authorised`. Each pattern is written to catch the assertion
  /// and not its denial.
  final forbidden = <String, RegExp>{
    'safe to work': RegExp(r'\bsafe\s+to\s+work\b', caseSensitive: false),
    'site safe': RegExp(r'\bsite\s+safe\b', caseSensitive: false),
    'area safe': RegExp(r'\barea\s+is\s+safe\b', caseSensitive: false),
    'H2S safe': RegExp(r'h(?:2|₂)s\s+safe\b', caseSensitive: false),
    'PTW approved': RegExp(
      r'\b(?:ptw|permit)\s+(?:is\s+)?approved\b',
      caseSensitive: false,
    ),
    'JSA approved': RegExp(
      r'\bjsa\s+(?:is\s+)?approved\b',
      caseSensitive: false,
    ),
    'PTW verified': RegExp(
      r'\b(?:ptw|permit|jsa)\s+(?:is\s+)?verified\b',
      caseSensitive: false,
    ),
    'work authorised': RegExp(
      r'\bwork\s+(?:is\s+)?authoris|\bwork\s+(?:is\s+)?authoriz',
      caseSensitive: false,
    ),
    'MRPL verified': RegExp(
      r'\b(?:mrpl\s+(?:verified|approved|certified)'
      r'|verified\s+by\s+mrpl'
      r'|official\s+mrpl'
      r'|connected\s+to\s+mrpl)\b',
      caseSensitive: false,
    ),
    'cleared for work': RegExp(
      r'\bcleared\s+for\s+work\b',
      caseSensitive: false,
    ),
    'permission to work': RegExp(
      r'\bpermission\s+to\s+work\b',
      caseSensitive: false,
    ),
  };

  /// Comment lines are skipped.
  ///
  /// The rule being enforced is "a worker must never read this on a screen",
  /// and a comment cannot appear on a screen. Comments also have to be able to
  /// *quote* the forbidden phrases in order to prohibit them — the validator's
  /// own documentation says a readiness result must never render "as anything
  /// resembling 'safe to work'", which is the rule, not a breach of it.
  ///
  /// A trailing comment on a line of code is still scanned. That is deliberate:
  /// the cost is a rare false positive, and the alternative is parsing Dart.
  bool isCommentLine(String line) {
    final t = line.trimLeft();
    return t.startsWith('//') || t.startsWith('*') || t.startsWith('/*');
  }

  /// Lines that legitimately contain a forbidden phrase because they exist to
  /// deny it. Kept explicit and tiny — an entry here is a decision, and a
  /// growing list is a signal that the copy has started arguing with itself.
  bool isDenial(String line) {
    final l = line.toLowerCase();
    return l.contains('never') ||
        l.contains('not ') ||
        l.contains("n't") ||
        l.contains('does not') ||
        l.contains('must not');
  }

  group('no screen may claim authority DoseBand does not have', () {
    final libDir = Directory('lib');

    test('lib/ is where the test thinks it is', () {
      // Guards against the whole suite silently passing because the working
      // directory moved and every glob returned nothing.
      expect(libDir.existsSync(), isTrue);
      expect(
        libDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart')),
        isNotEmpty,
      );
    });

    test('no forbidden authorisation wording appears in any Dart source', () {
      final offences = <String>[];

      for (final file in libDir.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (isCommentLine(line)) continue;
          for (final entry in forbidden.entries) {
            if (!entry.value.hasMatch(line)) continue;
            if (isDenial(line)) continue;
            offences.add(
              '${file.path}:${i + 1}  [${entry.key}]  ${line.trim()}',
            );
          }
        }
      }

      expect(
        offences,
        isEmpty,
        reason:
            'DoseBand does not authorise work. These lines claim otherwise:\n'
            '${offences.join('\n')}',
      );
    });

    test('the detector actually detects', () {
      // A wording test that cannot fail is worse than none: it reports safety
      // every run while checking nothing.
      const bad = 'This badge means you are SAFE TO WORK in the unit.';
      expect(
        forbidden.values.any((r) => r.hasMatch(bad)),
        isTrue,
        reason: 'the forbidden-phrase patterns no longer match a clear breach',
      );

      const alsoBad = 'PTW approved and JSA approved for this job.';
      expect(forbidden['PTW approved']!.hasMatch(alsoBad), isTrue);
      expect(forbidden['JSA approved']!.hasMatch(alsoBad), isTrue);
    });

    test('skipping comments does not skip code', () {
      // The comment exemption must not become a hole: a string literal on a
      // line that happens to start with whitespace is still code.
      const codeLine = "        label: 'Safe to work',";
      expect(isCommentLine(codeLine), isFalse);
      expect(forbidden['safe to work']!.hasMatch(codeLine), isTrue);

      const commentLine = '  /// never render as "safe to work".';
      expect(isCommentLine(commentLine), isTrue);
    });

    test('legitimate safety wording is not flagged', () {
      // The copy the product genuinely uses has to survive the detector,
      // otherwise the next person will weaken the patterns instead of the copy.
      const legitimate = [
        'It does not replace PTW, JSA or site safety requirements.',
        'DoseBand records the reference — it does not authorise the work.',
        'Ready for dosimetry confirms that DoseBand monitoring information is '
            'complete.',
        'This is not a gas detector and not an alarm.',
        'It does not mean the area or the work is safe.',
      ];
      for (final line in legitimate) {
        final hit = forbidden.entries
            .where((e) => e.value.hasMatch(line) && !isDenial(line))
            .map((e) => e.key);
        expect(hit, isEmpty, reason: line);
      }
    });
  });

  group('the readiness vocabulary stays honest', () {
    test('no requirement label implies authorisation', () {
      for (final r in WorkContextRequirement.values) {
        final label = r.label.toLowerCase();
        expect(label, isNot(contains('approved')), reason: r.name);
        expect(label, isNot(contains('safe')), reason: r.name);
        expect(label, isNot(contains('authoris')), reason: r.name);
        expect(label, isNot(contains('verified')), reason: r.name);
      }
    });

    test('no monitoring state reads as a verdict on the work', () {
      // Reaches the private label map through the public surface that renders
      // it, so the assertion tracks what a worker actually sees.
      const forbiddenWords = ['safe', 'approved', 'authoris', 'cleared'];
      for (final stage in WorkContextSummaryLabels.all) {
        for (final word in forbiddenWords) {
          expect(stage.toLowerCase(), isNot(contains(word)), reason: stage);
        }
      }
    });

    test('"ready for dosimetry" is the strongest claim made', () {
      expect(WorkContextSummaryLabels.all, contains('Ready for dosimetry'));
    });
  });
}
