import 'package:flutter_test/flutter_test.dart';
import 'package:katala/domain/enums/intent_type.dart';
import 'package:katala/domain/nlp/intent_detector.dart';
import 'package:katala/domain/nlp/models/normalized_transcript.dart';

void main() {
  group('Stage 2: IntentDetector', () {
    const detector = IntentDetector();

    test('matches English intent patterns from Appendix A.1', () {
      final patterns = [
        'remind me to buy groceries',
        'set a reminder for 5pm',
        'add reminder to call adam',
        'reminder to take meds',
        "don't forget to lock the door",
        'i need to check the oven',
        'remember to log off',
      ];

      for (final text in patterns) {
        final result = detector.detect(NormalizedTranscript(text: text, originalText: text));
        expect(result.intent, IntentType.general, reason: 'Failed on "$text"');
        expect(result.isExplicitPatternMatched, isTrue, reason: 'Explicit match failed on "$text"');
      }
    });

    test('matches Taglish intent patterns from Appendix A.2', () {
      final patterns = [
        'pa-remind mo ko tawagan si mama',
        'remind mo ako bumili ng bigas',
        'mag-remind na magluto',
        'ipaalala mo magbayad ng bill',
        'paremind naman pumunta sa bangko',
        'paalala bukas',
      ];

      for (final text in patterns) {
        final result = detector.detect(NormalizedTranscript(text: text, originalText: text));
        expect(result.intent, IntentType.general, reason: 'Failed on "$text"');
        expect(result.isExplicitPatternMatched, isTrue, reason: 'Explicit match failed on "$text"');
      }
    });

    test('unrecognized intents return GENERAL with isExplicitPatternMatched = false', () {
      final result = detector.detect(
        const NormalizedTranscript(
            text: 'what is the weather in manila', originalText: 'what is the weather in manila'),
      );
      expect(result.intent, IntentType.general);
      expect(result.isExplicitPatternMatched, isFalse);
    });
  });
}
