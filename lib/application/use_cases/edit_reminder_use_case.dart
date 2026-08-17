import '../../data/repositories/reminder_repository.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/enums/reminder_status.dart';
import '../../domain/errors.dart';
import '../../domain/nlp/clock.dart';
import '../../domain/result.dart';
import '../../platform/bridges/notification_bridge.dart';

/// Use case to edit an active reminder's content or trigger time with automatic notification rescheduling.
class EditReminderUseCase {
  final ReminderRepository repository;
  final NotificationBridge notificationBridge;
  final Clock clock;

  const EditReminderUseCase({
    required this.repository,
    required this.notificationBridge,
    required this.clock,
  });

  /// Edits an existing reminder.
  Future<Result<Reminder, AppError>> execute(Reminder updated) async {
    final existing = await repository.getById(updated.id);
    if (existing == null) {
      return const Result.failure(PersistenceFailed('Reminder not found'));
    }

    if (existing.isDeleted) {
      return const Result.failure(PersistenceFailed('Cannot edit a deleted reminder'));
    }

    if (existing.status == ReminderStatus.completed || existing.status == ReminderStatus.dismissed) {
      return Result.failure(InvalidStateTransition(existing.status, updated.status));
    }

    final timeChanged = existing.trigger?.scheduledTimeUtc != updated.trigger?.scheduledTimeUtc;

    if (timeChanged) {
      try {
        await notificationBridge.cancelForReminder(existing.id);
      } catch (e) {
        // Best effort
      }
    }

    Reminder persisted;
    try {
      persisted = await repository.update(updated, expectedVersion: existing.version);
    } catch (e) {
      return Result.failure(PersistenceFailed('Failed to update reminder: $e'));
    }

    if (timeChanged && (persisted.status == ReminderStatus.pending || persisted.status == ReminderStatus.snoozed)) {
      try {
        final notifId = await notificationBridge.schedule(persisted);
        await repository.updateTriggerScheduling(persisted.id, true, notifId);
        persisted = persisted.copyWith(
          trigger: persisted.trigger?.copyWith(
            notificationScheduled: true,
            notificationId: notifId,
          ),
        );
      } catch (e) {
        // Reconciliation will reschedule
      }
    }

    return Result.success(persisted);
  }
}
