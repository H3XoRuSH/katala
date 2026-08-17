import 'package:flutter_test/flutter_test.dart';
import 'package:katala/domain/nlp/entity_extractor.dart';
import 'package:katala/domain/nlp/models/normalized_transcript.dart';

void main() {
  group('Stage 3: EntityExtractor', () {
    const extractor = EntityExtractor();

    test('extracts URL first before other entities', () {
      const input = NormalizedTranscript(
        text: 'check https://katala.app at 5pm',
        originalText: 'check https://katala.app at 5pm',
      );
      final result = extractor.extract(input);
      expect(result.url, 'https://katala.app');
      expect(result.timeExpressionText, 'at 5pm');
      expect(result.title, 'Check');
    });

    test('extracts phone number before contact names', () {
      const input = NormalizedTranscript(
        text: 'call 09171234567 at noon',
        originalText: 'call 09171234567 at noon',
      );
      final result = extractor.extract(input);
      expect(result.phoneNumber, '09171234567');
      expect(result.timeExpressionText, 'at noon');
      expect(result.title, 'Call');
    });

    test('extracts English contact name and temporal expression', () {
      const input = NormalizedTranscript(
        text: 'call adam tomorrow at 3pm',
        originalText: 'call adam tomorrow at 3pm',
      );
      final result = extractor.extract(input);
      expect(result.contactName, 'adam');
      expect(result.title, 'Call adam');
      expect(result.timeExpressionText, 'tomorrow at 3pm');
    });

    test('extracts Taglish contact name ("tawagan si", "i-text si")', () {
      const input1 = NormalizedTranscript(
        text: 'tawagan si mama bukas ng 9am',
        originalText: 'tawagan si mama bukas ng 9am',
      );
      final result1 = extractor.extract(input1);
      expect(result1.contactName, 'mama');
      expect(result1.title, 'Tawagan si mama');
      expect(result1.timeExpressionText, 'bukas ng 9am');

      const input2 = NormalizedTranscript(
        text: 'i-text si ate mamayang 5pm',
        originalText: 'i-text si ate mamayang 5pm',
      );
      final result2 = extractor.extract(input2);
      expect(result2.contactName, 'ate');
      expect(result2.title, 'I-text si ate');
      expect(result2.timeExpressionText, 'mamayang 5pm');
    });

    test('extracts notes after note separator', () {
      const input = NormalizedTranscript(
        text: 'remind me to call teacher tomorrow at 4pm note: discuss math grades',
        originalText: 'remind me to call teacher tomorrow at 4pm note: discuss math grades',
      );
      final result = extractor.extract(input);
      expect(result.contactName, 'teacher');
      expect(result.notes, 'discuss math grades');
    });

    test('preserves proper noun capitalization from original transcript', () {
      const input = NormalizedTranscript(
        text: 'remind me to call gab in one minute',
        originalText: 'remind me to call Gab in one minute',
      );
      final result = extractor.extract(input);
      expect(result.contactName, 'Gab');
      expect(result.title, 'Call Gab');
      expect(result.timeExpressionText, 'in one minute');
    });
  });
}
