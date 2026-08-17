import '../../data/repositories/reminder_repository.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/enums/reminder_status.dart';
import '../../domain/errors.dart';
import '../../domain/nlp/clock.dart';
import '../../domain/result.dart';
import '../../platform/bridges/notification_bridge.dart';

/// Use case to soft delete a reminder and cancel its scheduled notification.
class DeleteReminderUseCase {
  final ReminderRepository repository;
  final NotificationBridge notificationBridge;
  final Clock clock;

  const DeleteReminderUseCase({
    required this.repository,
    required this.notificationBridge,
    required this.clock,
  });

  /// Soft deletes reminder [id].
  Future<Result<Reminder, AppError>> execute(String id) async {
    final reminder = await repository.getById(id);
    if (reminder == null) {
      return const Result.failure(PersistenceFailed('Reminder not found'));
    }

    try {
      await repository.softDelete(id, reminder.version);
    } catch (e) {
      return Result.failure(PersistenceFailed('Failed to delete reminder: $e'));
    }

    try {
      await notificationBridge.cancelForReminder(id);
      await repository.updateTriggerScheduling(id, false, null);
    } catch (e) {
      // Best-effort notification cancel
    }

    return Result.success(reminder.copyWith(
      isDeleted: true,
      deletedAt: clock.now(),
      version: reminder.version + 1,
    ));
  }
}

/// Use case to restore a soft-deleted reminder and re-schedule its notification.
class UndoDeleteReminderUseCase {
  final ReminderRepository repository;
  final NotificationBridge notificationBridge;
  final Clock clock;

  const UndoDeleteReminderUseCase({
    required this.repository,
    required this.notificationBridge,
    required this.clock,
  });

  /// Restores a soft-deleted reminder [id].
  Future<Result<Reminder, AppError>> execute(String id) async {
    final reminder = await repository.getById(id);
    if (reminder == null) {
      return const Result.failure(PersistenceFailed('Reminder not found'));
    }

    if (!reminder.isDeleted) {
      return Result.success(reminder);
    }

    final restoredReminder = Reminder(
      id: reminder.id,
      title: reminder.title,
      notes: reminder.notes,
      status: reminder.status,
      completedAt: reminder.completedAt,
      deletedAt: null,
      snoozeCount: reminder.snoozeCount,
      snoozeDurationMinutes: reminder.snoozeDurationMinutes,
      createdAt: reminder.createdAt,
      updatedAt: clock.now(),
      version: reminder.version,
      isDeleted: false,
      intentType: reminder.intentType,
      trigger: reminder.trigger,
      action: reminder.action,
    );

    Reminder persisted;
    try {
      persisted = await repository.update(restoredReminder, expectedVersion: reminder.version);
    } catch (e) {
      return Result.failure(PersistenceFailed('Failed to restore reminder: $e'));
    }

    // Re-schedule notification if reminder is active and scheduled time is in the future (or within 2m grace window if never fired)
    final isPendingOrSnoozed = persisted.status == ReminderStatus.pending || persisted.status == ReminderStatus.snoozed;
    final trigger = persisted.trigger;
    final isEligible = trigger != null &&
        (trigger.scheduledTimeUtc.isAfter(clock.now().toUtc()) ||
            (trigger.firedAt == null &&
                trigger.scheduledTimeUtc.isAfter(clock.now().toUtc().subtract(const Duration(minutes: 2)))));

    if (isPendingOrSnoozed && isEligible) {
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
        // Reconciliation will catch this on foreground
      }
    }

    return Result.success(persisted);
  }
}
