import '../../data/repositories/reminder_repository.dart';
import '../../domain/conflict_detector.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/entities/resolved_contact.dart';
import '../../domain/entities/validated_reminder.dart';
import '../../domain/errors.dart';
import '../../domain/nlp/clock.dart';
import '../../domain/nlp/nlp_pipeline.dart';
import '../../domain/result.dart';
import '../../platform/bridges/contact_bridge.dart';
import '../../platform/bridges/notification_bridge.dart';

/// Primary use case for parsing, resolving, checking conflicts, persisting, and scheduling reminders.
class CreateReminderUseCase {
  final NlpPipeline nlpPipeline;
  final ContactBridge contactBridge;
  final ConflictDetector conflictDetector;
  final ReminderRepository repository;
  final NotificationBridge notificationBridge;
  final Clock clock;

  const CreateReminderUseCase({
    required this.nlpPipeline,
    required this.contactBridge,
    required this.conflictDetector,
    required this.repository,
    required this.notificationBridge,
    required this.clock,
  });

  /// Executes the 10-step reminder creation flow from a raw speech transcript.
  Future<Result<Reminder, AppError>> executeFromTranscript(
    String transcript, {
    bool saveAnyway = false,
  }) async {
    // 1. NLP parsing
    final parsed = nlpPipeline.parse(transcript, clock: clock);

    // 2. Validation check
    if (parsed.issues.isNotEmpty) {
      return Result.failure(ValidationFailed(parsed.issues));
    }

    if (parsed.title == null || parsed.scheduledTime == null) {
      return const Result.failure(ValidationFailed([]));
    }

    // 3. Contact resolution at save-time (ARCHITECTURE.md M1)
    ResolvedContact? resolvedContact;
    if (parsed.contactName != null && parsed.contactName!.trim().isNotEmpty) {
      final matches = await contactBridge.resolve(parsed.contactName!);
      if (matches.length > 1) {
        return Result.failure(ContactDisambiguationRequired(parsed.contactName!, matches));
      } else if (matches.length == 1) {
        resolvedContact = matches.first;
      }
    }

    // 4. Construct validated reminder
    final validated = ValidatedReminder(
      title: parsed.title!,
      resolvedContact: resolvedContact,
      phoneNumber: resolvedContact?.phoneNumber ?? parsed.phoneNumber,
      validatedUrl: parsed.url,
      notes: parsed.notes,
      scheduledTime: parsed.scheduledTime!,
      timezone: parsed.timezone ?? clock.localTimezone(),
      intentType: parsed.intentType,
      originalTranscript: transcript,
    );

    return executeFromValidated(validated, saveAnyway: saveAnyway);
  }

  /// Persists and schedules an already validated reminder.
  Future<Result<Reminder, AppError>> executeFromValidated(
    ValidatedReminder validated, {
    bool saveAnyway = false,
  }) async {
    // 1. Conflict detection
    if (!saveAnyway) {
      final pendingReminders = await repository.getPending();
      final conflicts = conflictDetector.detectConflicts(validated.scheduledTime, pendingReminders);
      if (conflicts.isNotEmpty) {
        final alternative = conflictDetector.suggestAlternative(validated.scheduledTime, conflicts);
        return Result.failure(ConflictDetected(conflicts, suggestedAlternative: alternative));
      }
    }

    // 2. Atomic persistence in SQLite database
    Reminder persisted;
    try {
      persisted = await repository.insert(validated);
    } catch (e) {
      return Result.failure(PersistenceFailed('Failed to persist reminder: $e'));
    }

    // 3. OS notification scheduling (AFTER persistence per ADR-11)
    try {
      final notificationId = await notificationBridge.schedule(persisted);
      await repository.updateTriggerScheduling(persisted.id, true, notificationId);
      persisted = persisted.copyWith(
        trigger: persisted.trigger?.copyWith(
          notificationScheduled: true,
          notificationId: notificationId,
        ),
      );
    } catch (e) {
      // DB is authoritative: reminder remains safely saved, reconciliation will re-attempt scheduling
    }

    return Result.success(persisted);
  }
}
