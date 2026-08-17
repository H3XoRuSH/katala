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
import 'package:katala/domain/enums/reminder_status.dart';
import 'package:katala/domain/nlp/nlp_pipeline.dart';
import '../../test_helpers/fake_action_bridge.dart';
import '../../test_helpers/fake_clock.dart';
import '../../test_helpers/fake_contact_bridge.dart';
import '../../test_helpers/fake_notification_bridge.dart';

void main() {
  group('HandleNotificationActionUseCase', () {
    late AppDatabase db;
    late ReminderRepository repository;
    late FakeNotificationBridge notificationBridge;
    late FakeActionBridge actionBridge;
    late FakeClock fakeClock;
    late CreateReminderUseCase createUseCase;
    late HandleNotificationActionUseCase handleActionUseCase;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repository = ReminderRepositoryImpl(db);
      notificationBridge = FakeNotificationBridge();
      actionBridge = FakeActionBridge();
      fakeClock = FakeClock(DateTime.utc(2026, 8, 17, 10, 0), timezone: 'UTC');

      final contactBridge = FakeContactBridge([
        const ResolvedContact(
          platformId: 'c-1',
          displayName: 'Adam Smith',
          phoneNumber: '+639171234567',
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

      final completeUseCase = CompleteReminderUseCase(
        repository: repository,
        notificationBridge: notificationBridge,
        clock: fakeClock,
      );

      final snoozeUseCase = SnoozeReminderUseCase(
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
    });

    tearDown(() async {
      await db.close();
    });

    test('DONE action transitions reminder to COMPLETED', () async {
      final created = (await createUseCase.executeFromTranscript('Remind me to hydrate tomorrow at 9am')).valueOrNull!;

      final result = await handleActionUseCase.execute(created.id, 'DONE');
      expect(result.isSuccess, isTrue);

      final inDb = await repository.getById(created.id);
      expect(inDb?.status, ReminderStatus.completed);
    });

    test('SNOOZE action transitions reminder to SNOOZED', () async {
      final created = (await createUseCase.executeFromTranscript('Remind me to hydrate tomorrow at 9am')).valueOrNull!;

      final result = await handleActionUseCase.execute(created.id, 'SNOOZE');
      expect(result.isSuccess, isTrue);

      final inDb = await repository.getById(created.id);
      expect(inDb?.status, ReminderStatus.snoozed);
      expect(inDb?.snoozeCount, 1);
    });

    test('CALL action launches dialer and transitions reminder to COMPLETED', () async {
      final created = (await createUseCase.executeFromTranscript('Call Adam tomorrow at 3pm')).valueOrNull!;

      final result = await handleActionUseCase.execute(created.id, 'CALL');
      expect(result.isSuccess, isTrue);

      expect(actionBridge.launchedDialerNumbers, contains('+639171234567'));
      final inDb = await repository.getById(created.id);
      expect(inDb?.status, ReminderStatus.completed);
    });

    test('OPEN_URL action launches browser and transitions reminder to COMPLETED', () async {
      final created =
          (await createUseCase.executeFromTranscript('Check https://katala.app tomorrow at 5pm')).valueOrNull!;

      final result = await handleActionUseCase.execute(created.id, 'OPEN_LINK');
      expect(result.isSuccess, isTrue);

      expect(actionBridge.launchedUrls, contains('https://katala.app'));
      final inDb = await repository.getById(created.id);
      expect(inDb?.status, ReminderStatus.completed);
    });

    test('EDIT action returns openApp signal', () async {
      final result = await handleActionUseCase.execute('rem-123', 'EDIT');
      expect(result.isSuccess, isTrue);
    });
  });
}
