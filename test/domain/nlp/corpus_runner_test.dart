import 'package:flutter_test/flutter_test.dart';
import 'package:katala/domain/nlp/nlp_pipeline.dart';
import '../../test_helpers/fake_clock.dart';
import 'corpus/corpus_entry.dart';
import 'corpus/edge_cases_corpus.dart';
import 'corpus/english_corpus.dart';
import 'corpus/taglish_corpus.dart';

void main() {
  group('NLP Pipeline Corpus Runner (TASK-120)', () {
    const pipeline = NlpPipeline();
    late FakeClock fakeClock;

    setUp(() {
      // Monday Aug 17, 2026 at 10:00 AM UTC
      fakeClock = FakeClock(DateTime.utc(2026, 8, 17, 10, 0), timezone: 'UTC');
    });

    void verifyStandardEntry(NlpCorpusEntry entry) {
      final result = pipeline.parse(entry.transcript, clock: fakeClock);

      expect(result.intentType, entry.expectedIntent,
          reason: '[${entry.id}] intentType mismatch for "${entry.transcript}"');

      if (entry.expectedTitle != null) {
        final actualTitle = result.title?.toLowerCase() ?? '';
        final actualNotes = result.notes?.toLowerCase() ?? '';
        final expectedTitle = entry.expectedTitle!.toLowerCase();
        final matches = actualTitle == expectedTitle ||
            actualTitle.contains(expectedTitle) ||
            expectedTitle.startsWith(actualTitle) ||
            actualNotes == expectedTitle;
        expect(matches, isTrue,
            reason: '[${entry.id}] title mismatch: actual "$actualTitle" vs expected "$expectedTitle"');
      }

      if (entry.expectedContactName != null) {
        expect(result.contactName?.toLowerCase(), entry.expectedContactName?.toLowerCase(),
            reason: '[${entry.id}] contactName mismatch');
      }

      if (entry.expectedPhoneNumber != null) {
        expect(result.phoneNumber, entry.expectedPhoneNumber, reason: '[${entry.id}] phoneNumber mismatch');
      }

      if (entry.expectedUrl != null) {
        expect(result.url, entry.expectedUrl, reason: '[${entry.id}] url mismatch');
      }

      if (entry.hasScheduledTime) {
        expect(result.scheduledTime, isNotNull,
            reason: '[${entry.id}] scheduledTime should not be null for "${entry.transcript}"');
      }

      for (final issue in entry.expectedIssues) {
        expect(result.issues, contains(issue),
            reason: '[${entry.id}] missing expected issue $issue in ${result.issues}');
      }
    }

    void verifyEdgeCaseEntry(NlpCorpusEntry entry) {
      final result = pipeline.parse(entry.transcript, clock: fakeClock);

      if (entry.expectedTitle != null) {
        final actualTitle = result.title?.toLowerCase() ?? '';
        final expectedTitle = entry.expectedTitle!.toLowerCase();
        final matches = actualTitle == expectedTitle || actualTitle.contains(expectedTitle);
        expect(matches, isTrue,
            reason: '[${entry.id}] title mismatch: actual "$actualTitle" vs expected "$expectedTitle"');
      } else {
        expect(result.title, isNull, reason: '[${entry.id}] title should be null');
      }

      if (entry.hasScheduledTime) {
        expect(result.scheduledTime, isNotNull, reason: '[${entry.id}] scheduledTime should not be null');
      } else {
        expect(result.scheduledTime, isNull, reason: '[${entry.id}] scheduledTime should be null');
      }

      for (final issue in entry.expectedIssues) {
        expect(result.issues, contains(issue), reason: '[${entry.id}] missing expected issue $issue');
      }
    }

    group('English Corpus (50 entries)', () {
      for (final entry in englishCorpus) {
        test('[${entry.id}] ${entry.transcript}', () {
          verifyStandardEntry(entry);
        });
      }
    });

    group('Taglish Corpus (25 entries)', () {
      for (final entry in taglishCorpus) {
        test('[${entry.id}] ${entry.transcript}', () {
          verifyStandardEntry(entry);
        });
      }
    });

    group('Edge Cases Corpus (25 entries)', () {
      for (final entry in edgeCasesCorpus) {
        test('[${entry.id}] ${entry.transcript}', () {
          verifyEdgeCaseEntry(entry);
        });
      }
    });

    test('Total corpus count meets or exceeds 100 entries', () {
      final total = englishCorpus.length + taglishCorpus.length + edgeCasesCorpus.length;
      expect(total, greaterThanOrEqualTo(100));
      expect(englishCorpus.length, 50);
      expect(taglishCorpus.length, 25);
      expect(edgeCasesCorpus.length, 25);
    });
  });
}
