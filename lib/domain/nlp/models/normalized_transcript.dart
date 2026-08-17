/// Normalized transcript produced by Pre-Processor (Stage 1).
class NormalizedTranscript {
  final String text;
  final String originalText;

  const NormalizedTranscript({
    required this.text,
    required this.originalText,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NormalizedTranscript &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          originalText == other.originalText;

  @override
  int get hashCode => text.hashCode ^ originalText.hashCode;

  @override
  String toString() => 'NormalizedTranscript("$text")';
}
