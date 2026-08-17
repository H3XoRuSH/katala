import 'package:katala/domain/enums/intent_type.dart';
import 'package:katala/domain/enums/validation_issue.dart';

/// Single test case specification for the NLP test corpus.
class NlpCorpusEntry {
  final String id;
  final String transcript;
  final IntentType expectedIntent;
  final String? expectedTitle;
  final String? expectedContactName;
  final String? expectedPhoneNumber;
  final String? expectedUrl;
  final String? expectedNotes;
  final bool hasScheduledTime;
  final List<ValidationIssue> expectedIssues;

  const NlpCorpusEntry({
    required this.id,
    required this.transcript,
    this.expectedIntent = IntentType.general,
    this.expectedTitle,
    this.expectedContactName,
    this.expectedPhoneNumber,
    this.expectedUrl,
    this.expectedNotes,
    this.hasScheduledTime = true,
    this.expectedIssues = const [],
  });
}
