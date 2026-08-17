import '../../domain/entities/action.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/entities/trigger.dart';
import '../../domain/entities/validated_reminder.dart';
import '../../domain/enums/delivery_status.dart';
import '../../domain/enums/reminder_status.dart';

/// Exception thrown when an optimistic lock update fails due to version mismatch.
class OptimisticLockException implements Exception {
  final String reminderId;
  final int expectedVersion;

  const OptimisticLockException(this.reminderId, this.expectedVersion);

  @override
  String toString() => 'OptimisticLockException: reminder $reminderId has changed since version $expectedVersion';
}

/// Abstract contract for reminder persistence and reactive queries.
abstract class ReminderRepository {
  /// Inserts a validated reminder and its associated trigger and action in a single atomic transaction.
  Future<Reminder> insert(ValidatedReminder reminder);

  /// Inserts an existing reminder entity graph (reminder + trigger + action) in a single atomic transaction.
  Future<Reminder> insertRaw(Reminder reminder, Trigger trigger, Action? action);

  /// Updates a reminder with optimistic locking (`WHERE version = :expectedVersion`).
  /// Throws [OptimisticLockException] if version mismatch occurs and retry fails.
  Future<Reminder> update(Reminder reminder, {required int expectedVersion});

  /// Executes an optimistic state transition returning rows affected (0 or 1).
  Future<int> transitionState(
    String id,
    int expectedVersion,
    ReminderStatus newStatus, {
    DateTime? completedAt,
    DateTime? updatedAt,
  });

  /// Soft deletes a reminder with optimistic locking.
  Future<void> softDelete(String id, int expectedVersion);

  /// Retrieves a single reminder by ID with its trigger and action loaded.
  Future<Reminder?> getById(String id);

  /// Retrieves all pending and snoozed reminders (where isDeleted = 0).
  Future<List<Reminder>> getPending({DateTime? before});

  /// Retrieves overdue reminders where scheduled time <= [now] and status is pending or snoozed.
  Future<List<Reminder>> getOverdue(DateTime now);

  /// Retrieves reminders within a given time range.
  Future<List<Reminder>> getByTimeRange(DateTime start, DateTime end);

  /// Retrieves pending reminders sorted by scheduled time, with an optional limit.
  Future<List<Reminder>> getPendingSortedByTime({int? limit});

  /// Retrieves reminders conflicting with [scheduledTime] within ±[windowMinutes].
  Future<List<Reminder>> getConflicting(DateTime scheduledTime, {int windowMinutes = 15});

  /// Retrieves reminders associated with an OS notification ID.
  Future<List<Reminder>> getByNotificationId(int notificationId);

  /// Reactive stream of pending reminders.
  Stream<List<Reminder>> watchPending();

  /// Reactive stream of overdue reminders relative to [now].
  Stream<List<Reminder>> watchOverdue(DateTime now);

  /// Updates trigger notification scheduling state.
  Future<void> updateTriggerScheduling(String reminderId, bool scheduled, int? notificationId);

  /// Updates trigger delivery status.
  Future<void> updateTriggerDeliveryStatus(String reminderId, DeliveryStatus status);

  /// Updates trigger fired timestamp.
  Future<void> updateTriggerFiredAt(String reminderId, DateTime firedAt);

  /// Finds the trigger for a reminder.
  Future<Trigger?> findTriggerByReminderId(String reminderId);

  /// Finds the action for a reminder.
  Future<Action?> findActionByReminderId(String reminderId);

  /// Reactive stream of all active reminders (where isDeleted = 0).
  Stream<List<Reminder>> watchAll();

  /// Hard-deletes soft-deleted reminders older than [cutoff].
  Future<int> hardDeleteOlderThan(DateTime cutoff);

  /// Retrieves a value from the `app_metadata` key-value table.
  Future<String?> getMetadata(String key);

  /// Sets a key-value pair in the `app_metadata` table.
  Future<void> setMetadata(String key, String value);
}
