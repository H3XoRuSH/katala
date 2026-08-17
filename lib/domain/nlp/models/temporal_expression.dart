/// Classification of temporal expression ambiguity.
enum TemporalAmbiguity {
  none,
  bareNumber,
  relativeWithoutAnchor,
}

/// Extracted raw temporal expression phrase and metadata.
class TemporalExpression {
  final String rawText;
  final TemporalAmbiguity ambiguity;

  const TemporalExpression({
    required this.rawText,
    this.ambiguity = TemporalAmbiguity.none,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemporalExpression &&
          runtimeType == other.runtimeType &&
          rawText == other.rawText &&
          ambiguity == other.ambiguity;

  @override
  int get hashCode => rawText.hashCode ^ ambiguity.hashCode;

  @override
  String toString() => 'TemporalExpression("$rawText", ambiguity: $ambiguity)';
}

/// Result of resolving a temporal expression to a concrete [DateTime].
class TemporalResult {
  final DateTime? resolvedTime;
  final String timezone;
  final TemporalAmbiguity ambiguity;

  const TemporalResult({
    this.resolvedTime,
    this.timezone = 'UTC',
    this.ambiguity = TemporalAmbiguity.none,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemporalResult &&
          runtimeType == other.runtimeType &&
          resolvedTime == other.resolvedTime &&
          timezone == other.timezone &&
          ambiguity == other.ambiguity;

  @override
  int get hashCode => resolvedTime.hashCode ^ timezone.hashCode ^ ambiguity.hashCode;

  @override
  String toString() => 'TemporalResult($resolvedTime, tz: $timezone, ambiguity: $ambiguity)';
}
