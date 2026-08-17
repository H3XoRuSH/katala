import '../../data/repositories/reminder_repository.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/enums/reminder_status.dart';
import '../../domain/errors.dart';
import '../../domain/nlp/clock.dart';
import '../../domain/result.dart';
import '../../domain/state_machine.dart';
import '../../platform/bridges/notification_bridge.dart';

/// Use case to transition a reminder to COMPLETED and cancel its OS notification.
class CompleteReminderUseCase {
  final ReminderRepository repository;
  final NotificationBridge notificationBridge;
  final Clock clock;

  const CompleteReminderUseCase({
    required this.repository,
    required this.notificationBridge,
    required this.clock,
  });

  /// Transitions reminder [id] to COMPLETED status.
  Future<Result<Reminder, AppError>> execute(String id) async {
    final reminder = await repository.getById(id);
    if (reminder == null) {
      return const Result.failure(PersistenceFailed('Reminder not found'));
    }

    if (reminder.status == ReminderStatus.completed) {
      return const Result.failure(InvalidStateTransition(ReminderStatus.completed, ReminderStatus.completed));
    }

    final transitionResult = transition(reminder, ReminderStatus.completed, now: clock.now());
    if (transitionResult.isFailure) {
      return Result.failure(transitionResult.errorOrNull!);
    }

    final updatedReminder = transitionResult.valueOrNull!;

    try {
      await repository.transitionState(
        id,
        reminder.version,
        ReminderStatus.completed,
        completedAt: clock.now(),
        updatedAt: clock.now(),
      );
    } catch (e) {
      return Result.failure(PersistenceFailed('Failed to update reminder state: $e'));
    }

    try {
      await notificationBridge.cancelForReminder(id);
      await repository.updateTriggerScheduling(id, false, null);
    } catch (e) {
      // Best-effort notification cancel
    }

    return Result.success(updatedReminder);
  }
}
