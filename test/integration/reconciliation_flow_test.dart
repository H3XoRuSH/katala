import 'package:flutter_test/flutter_test.dart';
import 'package:katala/application/use_cases/reconcile_notifications_use_case.dart';
import 'package:katala/data/database/database.dart';
import 'package:katala/data/repositories/reminder_repository_impl.dart';
import 'package:katala/domain/entities/reminder.dart';
import 'package:katala/domain/entities/trigger.dart';
import 'package:katala/domain/enums/delivery_status.dart';
import 'package:katala/domain/enums/intent_type.dart';
import 'package:katala/domain/enums/reminder_status.dart';
import 'package:katala/domain/enums/trigger_type.dart';
import '../test_helpers/fake_clock.dart';
import '../test_helpers/fake_notification_bridge.dart';
import '../test_helpers/test_database.dart';

void main() {
  group('Reconciliation Flow Integration Test (TASK-121)', () {
    late AppDatabase db;
    late ReminderRepositoryImpl repository;
    late FakeNotificationBridge notificationBridge;
    late FakeClock clock;
    late ReconcileNotificationsUseCase reconcileUseCase;

    final initialTime = DateTime.utc(2026, 8, 17, 10, 0);

    setUp(() {
      db = AppDatabase(createInMemoryDatabaseConnection());
      repository = ReminderRepositoryImpl(db);
      notificationBridge = FakeNotificationBridge();
      clock = FakeClock(initialTime);

      reconcileUseCase = ReconcileNotificationsUseCase(
        repository: repository,
        notificationBridge: notificationBridge,
        clock: clock,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('1. Cancels orphaned OS notifications for completed or non-existent reminders', () async {
      // Add an orphan reminder directly to bridge with no DB match
      final orphanReminder = Reminder(
        id: 'orphan-1',
        title: 'Orphan reminder',
        status: ReminderStatus.completed,
        createdAt: initialTime,
        updatedAt: initialTime,
      );
      notificationBridge.scheduledNotifications[99999] = orphanReminder;

      final result = await reconcileUseCase.execute();
      expect(result.cancelledIds, contains(99999));
      expect(notificationBridge.cancelledNotificationIds, contains(99999));
    });

    test('2. Schedules notifications for pending reminders lacking scheduled OS alerts', () async {
      final scheduledTime = initialTime.add(const Duration(hours: 2));
      final reminder = Reminder(
        id: 'rem-unscheduled',
        title: 'Water plants',
        status: ReminderStatus.pending,
        intentType: IntentType.general,
        snoozeCount: 0,
        version: 1,
        createdAt: initialTime,
        updatedAt: initialTime,
      );
      final trigger = Trigger(
        id: 'trig-unscheduled',
        reminderId: reminder.id,
        triggerType: TriggerType.scheduledTime,
        scheduledTimeUtc: scheduledTime,
        notificationScheduled: false,
        deliveryStatus: DeliveryStatus.scheduled,
      );

      await repository.insertRaw(reminder, trigger, null);

      final result = await reconcileUseCase.execute();
      expect(result.scheduledIds, contains(reminder.id));

      final updated = await repository.getById(reminder.id);
      expect(updated?.trigger?.notificationScheduled, isTrue);
      expect(updated?.trigger?.notificationId, isNotNull);
      expect(notificationBridge.scheduledNotifications.containsKey(updated?.trigger?.notificationId), isTrue);
    });

    test('3. Detects missed deliveries when device woke up past scheduled trigger time', () async {
      // Set last reconciled at 08:00
      final lastReconciled = initialTime.subtract(const Duration(hours: 2));
      await repository.setMetadata('last_reconciled_at', lastReconciled.toIso8601String());

      // Create a reminder that was scheduled at 09:00 (between 08:00 and 10:00) with scheduled status
      final missedTime = initialTime.subtract(const Duration(hours: 1));
      final reminder = Reminder(
        id: 'rem-missed',
        title: 'Missed meeting',
        status: ReminderStatus.pending,
        intentType: IntentType.general,
        snoozeCount: 0,
        version: 1,
        createdAt: lastReconciled,
        updatedAt: lastReconciled,
      );
      final trigger = Trigger(
        id: 'trig-missed',
        reminderId: reminder.id,
        triggerType: TriggerType.scheduledTime,
        scheduledTimeUtc: missedTime,
        notificationScheduled: true,
        deliveryStatus: DeliveryStatus.scheduled,
        firedAt: null,
      );

      await repository.insertRaw(reminder, trigger, null);

      await reconcileUseCase.execute();

      final updated = await repository.getById(reminder.id);
      expect(updated?.trigger?.deliveryStatus, DeliveryStatus.deliveryUncertain);
    });

    test('4. Updates last_reconciled_at timestamp and hard deletes reminders deleted > 30 days ago', () async {
      final oldDeletedDate = initialTime.subtract(const Duration(days: 35));
      final oldDeleted = Reminder(
        id: 'rem-old-deleted',
        title: 'Ancient reminder',
        status: ReminderStatus.dismissed,
        isDeleted: true,
        deletedAt: oldDeletedDate,
        snoozeCount: 0,
        version: 1,
        createdAt: initialTime.subtract(const Duration(days: 40)),
        updatedAt: oldDeletedDate,
      );
      final trigger = Trigger(
        id: 'trig-old-deleted',
        reminderId: oldDeleted.id,
        triggerType: TriggerType.scheduledTime,
        scheduledTimeUtc: oldDeletedDate,
      );

      await repository.insertRaw(oldDeleted, trigger, null);

      await reconcileUseCase.execute();

      final metadata = await repository.getMetadata('last_reconciled_at');
      expect(metadata, equals(initialTime.toIso8601String()));

      final fetchedOld = await repository.getById(oldDeleted.id);
      expect(fetchedOld, isNull);
    });
  });
}
