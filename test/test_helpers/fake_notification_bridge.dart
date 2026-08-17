import 'package:katala/domain/entities/reminder.dart';
import 'package:katala/platform/bridges/notification_bridge.dart';

/// In-memory fake implementation of [NotificationBridge] for deterministic testing.
class FakeNotificationBridge implements NotificationBridge {
  final Map<int, Reminder> scheduledNotifications = {};
  final Map<String, int> reminderIdToNotificationId = {};
  final List<int> cancelledNotificationIds = [];
  final List<String> cancelledReminderIds = [];
  int _nextNotificationId = 1000;
  bool categoriesConfigured = false;
  int playSaveSoundCallCount = 0;
  final int maxNotifications;
  Exception? errorToThrow;

  FakeNotificationBridge({this.maxNotifications = 64, this.errorToThrow});

  @override
  int get maxPendingNotifications => maxNotifications;

  @override
  Future<void> configureCategories() async {
    categoriesConfigured = true;
  }

  @override
  Future<void> playSaveSound() async {
    playSaveSoundCallCount++;
  }

  @override
  Future<int> schedule(Reminder reminder) async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }

    // Idempotent: cancel existing if any
    if (reminderIdToNotificationId.containsKey(reminder.id)) {
      final existingId = reminderIdToNotificationId[reminder.id]!;
      await cancel(existingId);
    }

    final id = _nextNotificationId++;
    scheduledNotifications[id] = reminder;
    reminderIdToNotificationId[reminder.id] = id;
    return id;
  }

  @override
  Future<void> cancel(int notificationId) async {
    cancelledNotificationIds.add(notificationId);
    final reminder = scheduledNotifications.remove(notificationId);
    if (reminder != null) {
      reminderIdToNotificationId.remove(reminder.id);
    }
  }

  @override
  Future<void> cancelForReminder(String reminderId) async {
    cancelledReminderIds.add(reminderId);
    final notificationId = reminderIdToNotificationId.remove(reminderId);
    if (notificationId != null) {
      cancelledNotificationIds.add(notificationId);
      scheduledNotifications.remove(notificationId);
    }
  }

  @override
  Future<List<int>> getScheduledIds() async {
    return scheduledNotifications.keys.toList();
  }

  @override
  Future<ReconciliationResult> reconcile({
    required List<Reminder> toSchedule,
    required List<int> knownIds,
  }) async {
    final scheduledIds = <String>[];
    final failedIds = <String>[];
    final cancelledIds = <int>[];
    final errors = <String>[];

    final targetReminderIds = toSchedule.map((r) => r.id).toSet();

    // 1. Cancel orphans
    for (final id in List<int>.from(scheduledNotifications.keys)) {
      final reminder = scheduledNotifications[id];
      if (reminder == null || !targetReminderIds.contains(reminder.id)) {
        await cancel(id);
        cancelledIds.add(id);
      }
    }

    // 2. Schedule missing up to limit
    final allowedCount = toSchedule.length > maxNotifications ? maxNotifications : toSchedule.length;
    for (int i = 0; i < allowedCount; i++) {
      final reminder = toSchedule[i];
      if (!reminderIdToNotificationId.containsKey(reminder.id)) {
        try {
          await schedule(reminder);
          scheduledIds.add(reminder.id);
        } catch (e) {
          failedIds.add(reminder.id);
          errors.add(e.toString());
        }
      }
    }

    return ReconciliationResult(
      scheduledIds: scheduledIds,
      failedIds: failedIds,
      cancelledIds: cancelledIds,
      errors: errors,
    );
  }
}
