import '../enums/intent_type.dart';
import 'models/intent_classification.dart';
import 'models/normalized_transcript.dart';

/// Stage 2 of the deterministic NLP Pipeline: intent classification.
class IntentDetector {
  const IntentDetector();

  static final List<RegExp> _reminderIntentPatterns = [
    // English intent patterns (Appendix A.1)
    RegExp(r'\bremind me\b', caseSensitive: false),
    RegExp(r'\bset a reminder\b', caseSensitive: false),
    RegExp(r'\badd reminder\b', caseSensitive: false),
    RegExp(r'\breminder to\b', caseSensitive: false),
    RegExp(r"\bdon't forget\b", caseSensitive: false),
    RegExp(r'\bi need to\b', caseSensitive: false),
    RegExp(r'\bremember to\b', caseSensitive: false),
    RegExp(r'\bcreate reminder\b', caseSensitive: false),

    // Taglish intent patterns (Appendix A.2)
    RegExp(r'\bpa-?remind(\s+mo)?(\s+ko|\s+ako|\s+naman)?\b', caseSensitive: false),
    RegExp(r'\bremind mo (ko|ako|naman)\b', caseSensitive: false),
    RegExp(r'\bmag-?remind\b', caseSensitive: false),
    RegExp(r'\bipaalala mo\b', caseSensitive: false),
    RegExp(r'\bparemind\b', caseSensitive: false),
    RegExp(r'\bpaalala\b', caseSensitive: false),
  ];

  /// Detects the intent classification from [input].
  IntentClassification detect(NormalizedTranscript input) {
    if (input.text.isEmpty) {
      return const IntentClassification(
        intent: IntentType.general,
        isExplicitPatternMatched: false,
      );
    }

    for (final pattern in _reminderIntentPatterns) {
      if (pattern.hasMatch(input.text)) {
        return const IntentClassification(
          intent: IntentType.general,
          isExplicitPatternMatched: true,
        );
      }
    }

    // Default intent for all reminder-like inputs for MVP is GENERAL
    return const IntentClassification(
      intent: IntentType.general,
      isExplicitPatternMatched: false,
    );
  }
}
