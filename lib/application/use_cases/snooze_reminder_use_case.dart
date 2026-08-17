import '../../data/repositories/reminder_repository.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/enums/reminder_status.dart';
import '../../domain/errors.dart';
import '../../domain/nlp/clock.dart';
import '../../domain/result.dart';
import '../../domain/state_machine.dart';
import '../../platform/bridges/notification_bridge.dart';

/// Use case to snooze a reminder and schedule its follow-up notification.
class SnoozeReminderUseCase {
  final ReminderRepository repository;
  final NotificationBridge notificationBridge;
  final Clock clock;

  const SnoozeReminderUseCase({
    required this.repository,
    required this.notificationBridge,
    required this.clock,
  });

  /// Snoozes reminder [id] by [customDurationMinutes] (or default reminder snooze duration).
  Future<Result<Reminder, AppError>> execute(
    String id, {
    int? customDurationMinutes,
  }) async {
    final reminder = await repository.getById(id);
    if (reminder == null) {
      return const Result.failure(PersistenceFailed('Reminder not found'));
    }

    if (reminder.snoozeCount >= kMaxSnoozeCount) {
      return Result.failure(InvalidStateTransition(reminder.status, ReminderStatus.snoozed));
    }

    final transitionResult = transition(reminder, ReminderStatus.snoozed, now: clock.now());
    if (transitionResult.isFailure) {
      return Result.failure(transitionResult.errorOrNull!);
    }

    final duration = customDurationMinutes ?? reminder.snoozeDurationMinutes;
    final newScheduledTime = clock.now().add(Duration(minutes: duration));

    final updatedTrigger = reminder.trigger?.copyWith(
      scheduledTimeUtc: newScheduledTime.toUtc(),
      notificationScheduled: false,
    );

    final snoozedReminder = transitionResult.valueOrNull!.copyWith(
      trigger: updatedTrigger,
      snoozeDurationMinutes: duration,
    );

    Reminder persisted;
    try {
      persisted = await repository.update(snoozedReminder, expectedVersion: reminder.version);
    } catch (e) {
      return Result.failure(PersistenceFailed('Failed to persist snoozed reminder: $e'));
    }

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
      // Best-effort notification schedule
    }

    return Result.success(persisted);
  }
}
