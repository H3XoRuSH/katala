import 'entities/reminder.dart';
import 'entities/resolved_contact.dart';
import 'enums/reminder_status.dart';
import 'enums/speech_availability.dart';
import 'enums/validation_issue.dart';

/// Sealed base class for all Katala domain, application, and platform errors.
sealed class AppError {
  const AppError();

  /// Human-readable message suitable for UX representation.
  String get userMessage;

  /// Optional technical or debug details.
  String? get technicalDetails => null;
}

// ==========================================
// Domain Errors
// ==========================================

/// Error indicating validation issues in parsed reminder data.
final class ValidationFailed extends AppError {
  final List<ValidationIssue> issues;
  const ValidationFailed(this.issues);

  @override
  String get userMessage => 'Please provide the missing details for your reminder.';

  @override
  String get technicalDetails => 'Validation issues: ${issues.map((i) => i.value).join(', ')}';
}

/// Error indicating an overlapping schedule conflict within ±15 minutes.
final class ConflictDetected extends AppError {
  final List<Reminder> conflicts;
  final DateTime? suggestedAlternative;

  const ConflictDetected(this.conflicts, {this.suggestedAlternative});

  @override
  String get userMessage => 'You already have ${conflicts.length} reminder(s) around this time.';

  @override
  String get technicalDetails =>
      'Conflicts with: ${conflicts.map((r) => r.id).join(', ')}. Alternative: $suggestedAlternative';
}

/// Error indicating an invalid reminder lifecycle state transition.
final class InvalidStateTransition extends AppError {
  final ReminderStatus from;
  final ReminderStatus to;

  const InvalidStateTransition(this.from, this.to);

  @override
  String get userMessage => 'Cannot transition reminder from ${from.value} to ${to.value}.';

  @override
  String get technicalDetails => 'Invalid state machine transition: ${from.name} -> ${to.name}';
}

/// Error indicating the scheduled reminder time is in the past.
final class TimeInPast extends AppError {
  final DateTime scheduledTime;

  const TimeInPast(this.scheduledTime);

  @override
  String get userMessage => 'The scheduled time is in the past.';

  @override
  String get technicalDetails => 'Scheduled time ($scheduledTime) is earlier than reference now';
}

// ==========================================
// Application Errors
// ==========================================

/// Error indicating multiple contact matches require user disambiguation.
final class ContactDisambiguationRequired extends AppError {
  final String name;
  final List<ResolvedContact> candidates;

  const ContactDisambiguationRequired(this.name, this.candidates);

  @override
  String get userMessage => 'Multiple contacts found for "$name". Please select one.';

  @override
  String get technicalDetails => 'Disambiguation candidates: ${candidates.map((c) => c.displayName).join(', ')}';
}

/// Error indicating failure while scheduling notification with the OS.
final class SchedulingFailed extends AppError {
  final String reason;

  const SchedulingFailed(this.reason);

  @override
  String get userMessage => 'Reminder saved, but notification scheduling failed and will retry.';

  @override
  String get technicalDetails => reason;
}

/// Error indicating database persistence failure.
final class PersistenceFailed extends AppError {
  final String reason;
  final bool retryable;

  const PersistenceFailed(this.reason, {this.retryable = true});

  @override
  String get userMessage => "Couldn't save your reminder. Please try again.";

  @override
  String get technicalDetails => 'Persistence error (retryable: $retryable): $reason';
}

/// Error indicating failure while executing a notification action.
final class NotificationActionFailed extends AppError {
  final String reason;

  const NotificationActionFailed(this.reason);

  @override
  String get userMessage => 'Could not perform notification action.';

  @override
  String get technicalDetails => reason;
}

// ==========================================
// Platform Bridge Errors
// ==========================================

/// Error indicating on-device speech recognition is not available.
final class SpeechNotAvailable extends AppError {
  final SpeechAvailability availability;

  const SpeechNotAvailable(this.availability);

  @override
  String get userMessage => switch (availability) {
        SpeechAvailability.permissionDenied => 'Microphone permission is required for voice reminders.',
        SpeechAvailability.notSupported => 'Speech recognition is not supported on this device.',
        SpeechAvailability.unavailable => 'Voice recognition is currently unavailable. Type your reminder below.',
        SpeechAvailability.available => 'Speech service error.',
      };

  @override
  String get technicalDetails => 'Speech availability state: ${availability.value}';
}

/// Error indicating runtime permission denial.
final class PermissionDenied extends AppError {
  final String permission;

  const PermissionDenied(this.permission);

  @override
  String get userMessage => 'Permission "$permission" is needed for this feature.';

  @override
  String get technicalDetails => 'Permission denied: $permission';
}

/// Error indicating the iOS pending notification queue limit (64) is reached.
final class NotificationLimitReached extends AppError {
  final int count;

  const NotificationLimitReached([this.count = 64]);

  @override
  String get userMessage => 'Maximum scheduled notifications reached ($count).';

  @override
  String get technicalDetails => 'Notification limit reached: $count';
}

/// Error indicating inability to launch external URL, dialer, or SMS.
final class CannotLaunchUrl extends AppError {
  final String url;

  const CannotLaunchUrl(this.url);

  @override
  String get userMessage => 'Unable to open link or action.';

  @override
  String get technicalDetails => 'Cannot launch URL: $url';
}

// ==========================================
// NLP Errors
// ==========================================

/// Error indicating no recognizable reminder intent could be classified.
final class UnrecognizedIntent extends AppError {
  final String transcript;

  const UnrecognizedIntent(this.transcript);

  @override
  String get userMessage => 'Could not understand reminder intent.';

  @override
  String get technicalDetails => 'Unrecognized intent for transcript: "$transcript"';
}

/// Error indicating no entities could be extracted from input.
final class NoEntitiesExtracted extends AppError {
  final String transcript;

  const NoEntitiesExtracted(this.transcript);

  @override
  String get userMessage => "Couldn't identify what you want to be reminded about.";

  @override
  String get technicalDetails => 'No entities found in: "$transcript"';
}

/// Error indicating temporal expression could not be unambiguously resolved.
final class AmbiguousTimeResolution extends AppError {
  final String transcript;

  const AmbiguousTimeResolution(this.transcript);

  @override
  String get userMessage => 'Please clarify the time for your reminder.';

  @override
  String get technicalDetails => 'Ambiguous temporal resolution for transcript: "$transcript"';
}
