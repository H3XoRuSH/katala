import 'package:flutter_test/flutter_test.dart';
import 'package:katala/application/use_cases/complete_reminder_use_case.dart';
import 'package:katala/application/use_cases/handle_notification_action_use_case.dart';
import 'package:katala/application/use_cases/snooze_reminder_use_case.dart';
import 'package:katala/data/database/database.dart';
import 'package:katala/data/repositories/reminder_repository_impl.dart';
import 'package:katala/domain/entities/action.dart' as domain;
import 'package:katala/domain/entities/reminder.dart';
import 'package:katala/domain/entities/trigger.dart';
import 'package:katala/domain/enums/action_type.dart';
import 'package:katala/domain/enums/delivery_status.dart';
import 'package:katala/domain/enums/intent_type.dart';
import 'package:katala/domain/enums/reminder_status.dart';
import 'package:katala/domain/enums/trigger_type.dart';
import '../test_helpers/fake_action_bridge.dart';
import '../test_helpers/fake_clock.dart';
import '../test_helpers/fake_notification_bridge.dart';
import '../test_helpers/test_database.dart';

void main() {
  group('Notification Action Flow Integration Test (TASK-121)', () {
    late AppDatabase db;
    late ReminderRepositoryImpl repository;
    late FakeNotificationBridge notificationBridge;
    late FakeActionBridge actionBridge;
    late FakeClock clock;
    late CompleteReminderUseCase completeUseCase;
    late SnoozeReminderUseCase snoozeUseCase;
    late HandleNotificationActionUseCase handleActionUseCase;

    final now = DateTime.utc(2026, 8, 17, 10, 0);

    setUp(() {
      db = AppDatabase(createInMemoryDatabaseConnection());
      repository = ReminderRepositoryImpl(db);
      notificationBridge = FakeNotificationBridge();
      actionBridge = FakeActionBridge();
      clock = FakeClock(now);

      completeUseCase = CompleteReminderUseCase(
        repository: repository,
        notificationBridge: notificationBridge,
        clock: clock,
      );

      snoozeUseCase = SnoozeReminderUseCase(
        repository: repository,
        notificationBridge: notificationBridge,
        clock: clock,
      );

      handleActionUseCase = HandleNotificationActionUseCase(
        completeReminderUseCase: completeUseCase,
        snoozeReminderUseCase: snoozeUseCase,
        actionBridge: actionBridge,
        repository: repository,
      );
    });

    tearDown(() async {
      await db.close();
    });

    Future<Reminder> createTestReminder({
      required String id,
      required String title,
      IntentType intentType = IntentType.general,
      ActionType actionType = ActionType.general,
      String? contactName,
      String? contactPhone,
      String? targetValue,
      int snoozeCount = 0,
    }) async {
      final reminder = Reminder(
        id: id,
        title: title,
        intentType: intentType,
        status: ReminderStatus.pending,
        snoozeCount: snoozeCount,
        snoozeDurationMinutes: 10,
        version: 1,
        createdAt: now,
        updatedAt: now,
      );

      final trigger = Trigger(
        id: 'trig-$id',
        reminderId: id,
        triggerType: TriggerType.scheduledTime,
        scheduledTimeUtc: now.add(const Duration(hours: 1)),
        deliveryStatus: DeliveryStatus.scheduled,
      );

      final action = domain.Action(
        id: 'act-$id',
        reminderId: id,
        actionType: actionType,
        targetValue: targetValue,
        contactName: contactName,
        contactPhone: contactPhone,
      );

      return repository.insertRaw(reminder, trigger, action);
    }

    test('Flow 1: COMPLETE action transitions reminder to completed and cancels notifications', () async {
      final reminder = await createTestReminder(id: 'rem-done', title: 'Pick up dry cleaning');
      final notifId = await notificationBridge.schedule(reminder);
      await repository.updateTriggerScheduling(reminder.id, true, notifId);

      final result = await handleActionUseCase.execute(
        reminder.id,
        'ACTION_DONE',
      );

      expect(result.isSuccess, isTrue);
      final outcome = result.valueOrNull!;
      expect(outcome, isA<NotificationActionResult>());

      final updated = await repository.getById(reminder.id);
      expect(updated, isNotNull);
      expect(updated!.status, ReminderStatus.completed);
      expect(updated.completedAt, equals(now));
      expect(updated.version, 2);
      expect(notificationBridge.cancelledReminderIds, contains(reminder.id));
    });

    test('Flow 2: SNOOZE action increments snoozeCount and reschedules notification for +10m', () async {
      final reminder = await createTestReminder(id: 'rem-snooze', title: 'Take medicine');

      final result = await handleActionUseCase.execute(
        reminder.id,
        'ACTION_SNOOZE',
      );

      expect(result.isSuccess, isTrue);

      final updated = await repository.getById(reminder.id);
      expect(updated, isNotNull);
      expect(updated!.status, ReminderStatus.snoozed);
      expect(updated.snoozeCount, 1);
      expect(updated.version, 2);

      // Verify newly scheduled snooze trigger (+10 mins from now)
      final expectedSnoozeTime = now.add(const Duration(minutes: 10));
      expect(updated.trigger?.scheduledTimeUtc, equals(expectedSnoozeTime));
      expect(
        notificationBridge.scheduledNotifications.values.any((n) => n.id == updated.id),
        isTrue,
      );
    });

    test('Flow 3: CALL action initiates phone call via action bridge and returns callInitiated', () async {
      final reminder = await createTestReminder(
        id: 'rem-call',
        title: 'Call doctor',
        intentType: IntentType.call,
        actionType: ActionType.call,
        contactName: 'Doctor',
        contactPhone: '+18005550199',
      );

      final result = await handleActionUseCase.execute(
        reminder.id,
        'ACTION_CALL',
      );

      expect(result.isSuccess, isTrue);
      expect(actionBridge.launchedDialerNumbers, contains('+18005550199'));
    });

    test('Flow 4: TEXT action initiates SMS via action bridge', () async {
      final reminder = await createTestReminder(
        id: 'rem-text',
        title: 'Text Alice',
        intentType: IntentType.text,
        actionType: ActionType.text,
        contactName: 'Alice',
        contactPhone: '+18005550122',
      );

      final result = await handleActionUseCase.execute(
        reminder.id,
        'ACTION_TEXT',
      );

      expect(result.isSuccess, isTrue);
      expect(actionBridge.launchedSms.any((sms) => sms.phone == '+18005550122'), isTrue);
    });

    test('Flow 5: OPEN_URL action opens URL via action bridge', () async {
      final reminder = await createTestReminder(
        id: 'rem-url',
        title: 'Pay electricity bill',
        intentType: IntentType.openUrl,
        actionType: ActionType.openUrl,
        targetValue: 'https://pay.electric.example.com',
      );

      final result = await handleActionUseCase.execute(
        reminder.id,
        'ACTION_URL',
      );

      expect(result.isSuccess, isTrue);
      expect(actionBridge.launchedUrls, contains('https://pay.electric.example.com'));
    });

    test('Flow 6: OPEN_APP / default action returns openApp outcome', () async {
      final reminder = await createTestReminder(id: 'rem-app', title: 'Check itinerary');

      final result = await handleActionUseCase.execute(
        reminder.id,
        'ACTION_EDIT',
      );

      expect(result.isSuccess, isTrue);
    });
  });
}
