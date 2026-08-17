import '../entities/parsed_reminder.dart';
import '../enums/intent_type.dart';
import '../enums/validation_issue.dart';
import 'clock.dart';

/// Stage 5 of the deterministic NLP Pipeline: validation and explicit issue detection.
class Validator {
  const Validator();

  /// Validates [parsed] reminder data against business rules using [clock].
  List<ValidationIssue> validate(ParsedReminder parsed, {required Clock clock}) {
    final issues = <ValidationIssue>{};

    // 1. Missing Title check
    if (parsed.title == null || parsed.title!.trim().isEmpty) {
      issues.add(ValidationIssue.missingTitle);
    }

    // 2. Ambiguous Time check (propagated from Stage 4)
    if (parsed.issues.contains(ValidationIssue.ambiguousTime)) {
      issues.add(ValidationIssue.ambiguousTime);
    } else if (parsed.scheduledTime == null) {
      // 3. Missing Time check (only if not already flagged as ambiguous)
      issues.add(ValidationIssue.missingTime);
    }

    // 4. Time in past check
    if (parsed.scheduledTime != null && parsed.scheduledTime!.isBefore(clock.now())) {
      issues.add(ValidationIssue.timeInPast);
    }

    // 5. URL validity check
    if (parsed.url != null) {
      final url = parsed.url!;
      final uri = Uri.tryParse(url);
      if (uri == null || (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) || url.length > 2048) {
        issues.add(ValidationIssue.invalidUrl);
      }
    }

    // 6. Incomplete Action check (call/text without contact or phone)
    if (parsed.intentType == IntentType.call || parsed.intentType == IntentType.text) {
      final hasContact = parsed.contactName != null && parsed.contactName!.trim().isNotEmpty;
      final hasPhone = parsed.phoneNumber != null && parsed.phoneNumber!.trim().isNotEmpty;
      if (!hasContact && !hasPhone) {
        issues.add(ValidationIssue.incompleteAction);
      }
    }

    // Retain any other upstream issues
    for (final issue in parsed.issues) {
      issues.add(issue);
    }

    return issues.toList();
  }
}
