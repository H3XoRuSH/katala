import '../../enums/intent_type.dart';

/// Intent classification output produced by Intent Detector (Stage 2).
class IntentClassification {
  final IntentType intent;
  final bool isExplicitPatternMatched;

  const IntentClassification({
    required this.intent,
    this.isExplicitPatternMatched = true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IntentClassification &&
          runtimeType == other.runtimeType &&
          intent == other.intent &&
          isExplicitPatternMatched == other.isExplicitPatternMatched;

  @override
  int get hashCode => intent.hashCode ^ isExplicitPatternMatched.hashCode;

  @override
  String toString() => 'IntentClassification($intent, matched: $isExplicitPatternMatched)';
}
