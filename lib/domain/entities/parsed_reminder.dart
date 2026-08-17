import '../enums/intent_type.dart';
import '../enums/validation_issue.dart';

/// Intermediate output of the NLP pipeline prior to contact resolution and final validation.
class ParsedReminder {
  final String? title;
  final String? contactName;
  final String? url;
  final String? phoneNumber;
  final String? notes;
  final DateTime? scheduledTime;
  final String? timezone;
  final IntentType intentType;
  final List<ValidationIssue> issues;
  final String originalTranscript;

  const ParsedReminder({
    this.title,
    this.contactName,
    this.url,
    this.phoneNumber,
    this.notes,
    this.scheduledTime,
    this.timezone,
    this.intentType = IntentType.general,
    this.issues = const [],
    required this.originalTranscript,
  });

  ParsedReminder copyWith({
    String? title,
    String? contactName,
    String? url,
    String? phoneNumber,
    String? notes,
    DateTime? scheduledTime,
    String? timezone,
    IntentType? intentType,
    List<ValidationIssue>? issues,
    String? originalTranscript,
  }) {
    return ParsedReminder(
      title: title ?? this.title,
      contactName: contactName ?? this.contactName,
      url: url ?? this.url,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      notes: notes ?? this.notes,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      timezone: timezone ?? this.timezone,
      intentType: intentType ?? this.intentType,
      issues: issues ?? this.issues,
      originalTranscript: originalTranscript ?? this.originalTranscript,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParsedReminder &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          contactName == other.contactName &&
          url == other.url &&
          phoneNumber == other.phoneNumber &&
          notes == other.notes &&
          scheduledTime == other.scheduledTime &&
          timezone == other.timezone &&
          intentType == other.intentType &&
          originalTranscript == other.originalTranscript;

  @override
  int get hashCode =>
      title.hashCode ^
      contactName.hashCode ^
      url.hashCode ^
      phoneNumber.hashCode ^
      notes.hashCode ^
      scheduledTime.hashCode ^
      timezone.hashCode ^
      intentType.hashCode ^
      originalTranscript.hashCode;

  @override
  String toString() =>
      'ParsedReminder(title: "$title", intent: $intentType, time: $scheduledTime, tz: $timezone, issues: $issues)';
}
