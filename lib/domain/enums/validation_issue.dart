/// Deterministic issues discovered during reminder NLP parsing and validation.
enum ValidationIssue {
  missingTitle('missingTitle'),
  missingTime('missingTime'),
  ambiguousTime('ambiguousTime'),
  ambiguousContact('ambiguousContact'),
  unresolvedContact('unresolvedContact'),
  invalidUrl('invalidUrl'),
  timeInPast('timeInPast'),
  unrecognizedIntent('unrecognizedIntent'),
  incompleteAction('incompleteAction'),
  contactNotFound('contactNotFound');

  final String value;
  const ValidationIssue(this.value);

  static ValidationIssue fromValue(String value) {
    return ValidationIssue.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Unknown ValidationIssue value: $value'),
    );
  }
}
