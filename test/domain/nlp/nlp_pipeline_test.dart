import 'package:flutter_test/flutter_test.dart';
import 'package:katala/domain/nlp/nlp_pipeline.dart';
import '../../test_helpers/fake_clock.dart';
import 'corpus/edge_cases_corpus.dart';
import 'corpus/english_corpus.dart';
import 'corpus/taglish_corpus.dart';

void main() {
  group('NlpPipeline Full Integration & Test Corpus', () {
    const pipeline = NlpPipeline();
    late FakeClock fakeClock;

    setUp(() {
      // Monday Aug 17, 2026 at 10:00 AM UTC
      fakeClock = FakeClock(DateTime.utc(2026, 8, 17, 10, 0), timezone: 'UTC');
    });

    test('Pipeline is completely deterministic (same input + FakeClock = identical output)', () {
      const transcript = 'Remind me to call Adam tomorrow at 3pm';
      final run1 = pipeline.parse(transcript, clock: fakeClock);
      final run2 = pipeline.parse(transcript, clock: fakeClock);

      expect(run1, equals(run2));
      expect(run1.hashCode, equals(run2.hashCode));
    });

    group('English Test Corpus (50 Cases)', () {
      for (final entry in englishCorpus) {
        test('[${entry.id}] "${entry.transcript}"', () {
          final result = pipeline.parse(entry.transcript, clock: fakeClock);

          expect(result.intentType, entry.expectedIntent, reason: '[${entry.id}] intentType mismatch');
          if (entry.expectedTitle != null) {
            expect(result.title?.toLowerCase(), entry.expectedTitle?.toLowerCase(),
                reason: '[${entry.id}] title mismatch');
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
            expect(result.scheduledTime, isNotNull, reason: '[${entry.id}] scheduledTime should not be null');
          }
          for (final issue in entry.expectedIssues) {
            expect(result.issues, contains(issue), reason: '[${entry.id}] missing expected issue $issue');
          }
        });
      }
    });

    group('Taglish Test Corpus (25 Cases)', () {
      for (final entry in taglishCorpus) {
        test('[${entry.id}] "${entry.transcript}"', () {
          final result = pipeline.parse(entry.transcript, clock: fakeClock);

          expect(result.intentType, entry.expectedIntent, reason: '[${entry.id}] intentType mismatch');
          if (entry.expectedTitle != null) {
            expect(result.title?.toLowerCase(), entry.expectedTitle?.toLowerCase(),
                reason: '[${entry.id}] title mismatch');
          }
          if (entry.expectedContactName != null) {
            expect(result.contactName?.toLowerCase(), entry.expectedContactName?.toLowerCase(),
                reason: '[${entry.id}] contactName mismatch');
          }
          if (entry.hasScheduledTime) {
            expect(result.scheduledTime, isNotNull, reason: '[${entry.id}] scheduledTime should not be null');
          }
          for (final issue in entry.expectedIssues) {
            expect(result.issues, contains(issue), reason: '[${entry.id}] missing expected issue $issue');
          }
        });
      }
    });

    group('Edge Cases Test Corpus (25 Cases)', () {
      for (final entry in edgeCasesCorpus) {
        test('[${entry.id}] "${entry.transcript}"', () {
          final result = pipeline.parse(entry.transcript, clock: fakeClock);

          if (entry.expectedTitle != null) {
            expect(result.title?.toLowerCase(), entry.expectedTitle?.toLowerCase(),
                reason: '[${entry.id}] title mismatch');
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
        });
      }
    });
  });
}
