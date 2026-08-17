import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/application/use_cases/create_reminder_use_case.dart';
import 'package:katala/application/use_cases/edit_reminder_use_case.dart';
import 'package:katala/data/database/database.dart';
import 'package:katala/data/repositories/reminder_repository.dart';
import 'package:katala/data/repositories/reminder_repository_impl.dart';
import 'package:katala/domain/conflict_detector.dart';
import 'package:katala/domain/nlp/nlp_pipeline.dart';
import '../../test_helpers/fake_clock.dart';
import '../../test_helpers/fake_contact_bridge.dart';
import '../../test_helpers/fake_notification_bridge.dart';

void main() {
  group('EditReminderUseCase', () {
    late AppDatabase db;
    late ReminderRepository repository;
    late FakeNotificationBridge notificationBridge;
    late FakeClock fakeClock;
    late CreateReminderUseCase createUseCase;
    late EditReminderUseCase editUseCase;

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

      editUseCase = EditReminderUseCase(
        repository: repository,
        notificationBridge: notificationBridge,
        clock: fakeClock,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Updating title persists without rescheduling notification', () async {
      final created = (await createUseCase.executeFromTranscript('Remind me to run tomorrow at 6am')).valueOrNull!;
      final originalNotifId = created.trigger?.notificationId;

      final updated = created.copyWith(title: 'Go for a run');
      final result = await editUseCase.execute(updated);

      expect(result.isSuccess, isTrue);
      final inDb = await repository.getById(created.id);
      expect(inDb?.title, 'Go for a run');
      expect(inDb?.trigger?.notificationId, originalNotifId);
    });

    test('Updating scheduled time cancels old notification and schedules new one', () async {
      final created = (await createUseCase.executeFromTranscript('Remind me to run tomorrow at 6am')).valueOrNull!;
      final originalNotifId = created.trigger?.notificationId;

      final newTime = DateTime.utc(2026, 8, 18, 9, 0);
      final updated = created.copyWith(
        trigger: created.trigger?.copyWith(scheduledTimeUtc: newTime),
      );

      final result = await editUseCase.execute(updated);
      expect(result.isSuccess, isTrue);

      final inDb = await repository.getById(created.id);
      expect(inDb?.trigger?.scheduledTimeUtc, newTime);
      expect(inDb?.trigger?.notificationId, isNot(equals(originalNotifId)));
      expect(await notificationBridge.getScheduledIds(), isNot(contains(originalNotifId)));
    });
  });
}
