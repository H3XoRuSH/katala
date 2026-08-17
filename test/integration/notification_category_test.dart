import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/application/use_cases/complete_reminder_use_case.dart';
import 'package:katala/application/use_cases/create_reminder_use_case.dart';
import 'package:katala/application/use_cases/handle_notification_action_use_case.dart';
import 'package:katala/application/use_cases/snooze_reminder_use_case.dart';
import 'package:katala/data/database/database.dart';
import 'package:katala/data/repositories/reminder_repository.dart';
import 'package:katala/data/repositories/reminder_repository_impl.dart';
import 'package:katala/domain/conflict_detector.dart';
import 'package:katala/domain/entities/resolved_contact.dart';
import 'package:katala/domain/enums/action_type.dart';
import 'package:katala/domain/enums/intent_type.dart';
import 'package:katala/domain/enums/notification_category.dart';
import 'package:katala/domain/enums/reminder_status.dart';
import 'package:katala/domain/nlp/nlp_pipeline.dart';
import 'package:katala/platform/bridges/notification_bridge.dart';
import '../test_helpers/fake_action_bridge.dart';
import '../test_helpers/fake_clock.dart';
import '../test_helpers/fake_contact_bridge.dart';
import '../test_helpers/fake_notification_bridge.dart';

void main() {
  group('TASK-110: Notification Category Coordination & Action Response Integration', () {
    late AppDatabase db;
    late ReminderRepository repository;
    late FakeNotificationBridge notificationBridge;
    late FakeActionBridge actionBridge;
    late FakeClock fakeClock;
    late CreateReminderUseCase createUseCase;
    late CompleteReminderUseCase completeUseCase;
    late SnoozeReminderUseCase snoozeUseCase;
    late HandleNotificationActionUseCase handleActionUseCase;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repository = ReminderRepositoryImpl(db);
      notificationBridge = FakeNotificationBridge();
      actionBridge = FakeActionBridge();
      fakeClock = FakeClock(DateTime.utc(2026, 8, 17, 10, 0), timezone: 'UTC');

      final contactBridge = FakeContactBridge([
        const ResolvedContact(
          platformId: 'c-1',
          displayName: 'John Doe',
          phoneNumber: '+15551234567',
        ),
        const ResolvedContact(
          platformId: 'c-2',
          displayName: 'Sarah Connor',
          phoneNumber: '+15559876543',
        ),
      ]);

      createUseCase = CreateReminderUseCase(
        nlpPipeline: const NlpPipeline(),
        contactBridge: contactBridge,
        conflictDetector: const ConflictDetector(),
        repository: repository,
        notificationBridge: notificationBridge,
        clock: fakeClock,
      );

      completeUseCase = CompleteReminderUseCase(
        repository: repository,
        notificationBridge: notificationBridge,
        clock: fakeClock,
      );

      snoozeUseCase = SnoozeReminderUseCase(
        repository: repository,
        notificationBridge: notificationBridge,
        clock: fakeClock,
      );

      handleActionUseCase = HandleNotificationActionUseCase(
        completeReminderUseCase: completeUseCase,
        snoozeReminderUseCase: snoozeUseCase,
        actionBridge: actionBridge,
        repository: repository,
      );

      // Step 1: Register categories via NotificationBridge
      await notificationBridge.configureCategories();
    });

    tearDown(() async {
      await db.close();
    });

    test('Category identifiers and action identifiers match specification constants', () {
      expect(notificationBridge.categoriesConfigured, isTrue);

      // Verify category strings match
      expect(NotificationCategory.general.value, equals(NotificationBridge.categoryGeneral));
      expect(NotificationCategory.call.value, equals(NotificationBridge.categoryCall));
      expect(NotificationCategory.text.value, equals(NotificationBridge.categoryText));
      expect(NotificationCategory.url.value, equals(NotificationBridge.categoryUrl));

      expect(NotificationBridge.categoryGeneral, equals('REMINDER_GENERAL'));
      expect(NotificationBridge.categoryCall, equals('REMINDER_CALL'));
      expect(NotificationBridge.categoryText, equals('REMINDER_TEXT'));
      expect(NotificationBridge.categoryUrl, equals('REMINDER_URL'));

      expect(NotificationBridge.actionDone, equals('ACTION_DONE'));
      expect(NotificationBridge.actionSnooze, equals('ACTION_SNOOZE'));
      expect(NotificationBridge.actionCall, equals('ACTION_CALL'));
      expect(NotificationBridge.actionText, equals('ACTION_TEXT'));
      expect(NotificationBridge.actionUrl, equals('ACTION_URL'));
      expect(NotificationBridge.actionEdit, equals('ACTION_EDIT'));
    });

    test('GENERAL Category: schedule notification and execute ACTION_DONE & ACTION_SNOOZE', () async {
      final createResult = await createUseCase.executeFromTranscript('Buy groceries tomorrow at 5pm');
      final reminder = createResult.valueOrNull!;
      expect(reminder.intentType, equals(IntentType.general));
      expect(notificationBridge.scheduledNotifications.containsKey(reminder.trigger!.notificationId), isTrue);

      // Action: ACTION_DONE
      final doneResult = await handleActionUseCase.execute(reminder.id, NotificationBridge.actionDone);
      expect(doneResult.isSuccess, isTrue);

      final updated = await repository.getById(reminder.id);
      expect(updated?.status, equals(ReminderStatus.completed));
      expect(updated?.trigger?.notificationScheduled, isFalse);

      // Test ACTION_SNOOZE on another reminder
      final r2 = (await createUseCase.executeFromTranscript('Take medicine tomorrow at 8am')).valueOrNull!;
      final snoozeResult = await handleActionUseCase.execute(
        r2.id,
        NotificationBridge.actionSnooze,
        snoozeDurationMinutes: 10,
      );
      expect(snoozeResult.isSuccess, isTrue);

      final snoozed = await repository.getById(r2.id);
      expect(snoozed?.status, equals(ReminderStatus.snoozed));
      expect(snoozed?.trigger?.scheduledTimeUtc, equals(fakeClock.now().add(const Duration(minutes: 10))));
    });

    test('CALL Category: schedule notification and execute ACTION_CALL', () async {
      final createResult = await createUseCase.executeFromTranscript('Call John tomorrow at 10am');
      final reminder = createResult.valueOrNull!;
      expect(reminder.intentType, equals(IntentType.call));
      expect(reminder.action?.actionType, equals(ActionType.call));

      final actionResult = await handleActionUseCase.execute(reminder.id, NotificationBridge.actionCall);
      expect(actionResult.isSuccess, isTrue);
      expect(actionBridge.launchedDialerNumbers, contains('+15551234567'));

      final updated = await repository.getById(reminder.id);
      expect(updated?.status, equals(ReminderStatus.completed));
    });

    test('TEXT Category: schedule notification and execute ACTION_TEXT', () async {
      final createResult = await createUseCase.executeFromTranscript('Text Sarah tomorrow at 11am');
      final reminder = createResult.valueOrNull!;
      expect(reminder.intentType, equals(IntentType.text));
      expect(reminder.action?.actionType, equals(ActionType.text));

      final actionResult = await handleActionUseCase.execute(reminder.id, NotificationBridge.actionText);
      expect(actionResult.isSuccess, isTrue);
      expect(actionBridge.launchedSms.map((s) => s.phone), contains('+15559876543'));

      final updated = await repository.getById(reminder.id);
      expect(updated?.status, equals(ReminderStatus.completed));
    });

    test('URL Category: schedule notification and execute ACTION_URL', () async {
      final createResult = await createUseCase.executeFromTranscript('Check https://flutter.dev tomorrow at 9am');
      final reminder = createResult.valueOrNull!;
      expect(reminder.intentType, equals(IntentType.openUrl));
      expect(reminder.action?.actionType, equals(ActionType.openUrl));

      final actionResult = await handleActionUseCase.execute(reminder.id, NotificationBridge.actionUrl);
      expect(actionResult.isSuccess, isTrue);
      expect(actionBridge.launchedUrls, contains('https://flutter.dev'));

      final updated = await repository.getById(reminder.id);
      expect(updated?.status, equals(ReminderStatus.completed));
    });

    test('ACTION_EDIT returns openApp without completing reminder', () async {
      final createResult = await createUseCase.executeFromTranscript('Prepare presentation tomorrow at 3pm');
      final reminder = createResult.valueOrNull!;

      final actionResult = await handleActionUseCase.execute(reminder.id, NotificationBridge.actionEdit);
      expect(actionResult.isSuccess, isTrue);

      final unChanged = await repository.getById(reminder.id);
      expect(unChanged?.status, equals(ReminderStatus.pending));
    });
  });
}
