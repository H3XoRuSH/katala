import '../enums/intent_type.dart';
import 'resolved_contact.dart';

/// Fully validated reminder input ready for repository persistence.
class ValidatedReminder {
  final String title;
  final ResolvedContact? resolvedContact;
  final String? validatedUrl;
  final String? phoneNumber;
  final String? notes;
  final DateTime scheduledTime;
  final String timezone;
  final IntentType intentType;
  final String originalTranscript;

  const ValidatedReminder({
    required this.title,
    this.resolvedContact,
    this.validatedUrl,
    this.phoneNumber,
    this.notes,
    required this.scheduledTime,
    this.timezone = 'UTC',
    this.intentType = IntentType.general,
    required this.originalTranscript,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValidatedReminder &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          resolvedContact == other.resolvedContact &&
          validatedUrl == other.validatedUrl &&
          phoneNumber == other.phoneNumber &&
          notes == other.notes &&
          scheduledTime == other.scheduledTime &&
          timezone == other.timezone &&
          intentType == other.intentType &&
          originalTranscript == other.originalTranscript;

  @override
  int get hashCode =>
      title.hashCode ^
      resolvedContact.hashCode ^
      validatedUrl.hashCode ^
      phoneNumber.hashCode ^
      notes.hashCode ^
      scheduledTime.hashCode ^
      timezone.hashCode ^
      intentType.hashCode ^
      originalTranscript.hashCode;

  @override
  String toString() =>
      'ValidatedReminder(title: "$title", intent: $intentType, time: $scheduledTime, tz: $timezone, contact: $resolvedContact)';
}
