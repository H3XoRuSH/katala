import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/application/use_cases/create_reminder_use_case.dart';
import 'package:katala/application/use_cases/snooze_reminder_use_case.dart';
import 'package:katala/data/database/database.dart';
import 'package:katala/data/repositories/reminder_repository.dart';
import 'package:katala/data/repositories/reminder_repository_impl.dart';
import 'package:katala/domain/conflict_detector.dart';
import 'package:katala/domain/enums/reminder_status.dart';
import 'package:katala/domain/errors.dart';
import 'package:katala/domain/nlp/nlp_pipeline.dart';
import '../../test_helpers/fake_clock.dart';
import '../../test_helpers/fake_contact_bridge.dart';
import '../../test_helpers/fake_notification_bridge.dart';

void main() {
  group('SnoozeReminderUseCase', () {
    late AppDatabase db;
    late ReminderRepository repository;
    late FakeNotificationBridge notificationBridge;
    late FakeClock fakeClock;
    late CreateReminderUseCase createUseCase;
    late SnoozeReminderUseCase snoozeUseCase;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repository = ReminderRepositoryImpl(db);
      notificationBridge = FakeNotificationBridge();
      fakeClock = FakeClock(DateTime.utc(2026, 8, 17, 10, 0), timezone: 'UTC');

      createUseCase = CreateReminderUseCase(
        nlpPipeline: const NlpPipeline(),
        contactBridge: FakeContactBridge(),
        conflictDetector: const ConflictDetector(),
        repository: repository,
        notificationBridge: notificationBridge,
        clock: fakeClock,
      );

      snoozeUseCase = SnoozeReminderUseCase(
        repository: repository,
        notificationBridge: notificationBridge,
        clock: fakeClock,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Transitions PENDING reminder to SNOOZED and reschedules notification', () async {
      final created = (await createUseCase.executeFromTranscript('Remind me to workout tomorrow at 7am')).valueOrNull!;

      final result = await snoozeUseCase.execute(created.id, customDurationMinutes: 15);
      expect(result.isSuccess, isTrue);

      final snoozed = await repository.getById(created.id);
      expect(snoozed?.status, ReminderStatus.snoozed);
      expect(snoozed?.snoozeCount, 1);
      expect(snoozed?.version, 2);
      expect(snoozed?.trigger?.scheduledTimeUtc, fakeClock.now().add(const Duration(minutes: 15)));
    });

    test('11th snooze attempt is blocked by guard (snooze_count < 10)', () async {
      final created = (await createUseCase.executeFromTranscript('Remind me to workout tomorrow at 7am')).valueOrNull!;

      var currentId = created.id;
      // Perform 10 snoozes
      for (int i = 0; i < 10; i++) {
        final res = await snoozeUseCase.execute(currentId, customDurationMinutes: 10);
        expect(res.isSuccess, isTrue);
      }

      final reminderAfter10 = await repository.getById(currentId);
      expect(reminderAfter10?.snoozeCount, 10);

      // 11th snooze must fail
      final result11 = await snoozeUseCase.execute(currentId, customDurationMinutes: 10);
      expect(result11.isFailure, isTrue);
      expect(result11.errorOrNull, isA<InvalidStateTransition>());
    });
  });
}
