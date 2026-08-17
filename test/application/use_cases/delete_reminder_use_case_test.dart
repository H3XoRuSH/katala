import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/application/use_cases/create_reminder_use_case.dart';
import 'package:katala/application/use_cases/delete_reminder_use_case.dart';
import 'package:katala/data/database/database.dart';
import 'package:katala/data/repositories/reminder_repository.dart';
import 'package:katala/data/repositories/reminder_repository_impl.dart';
import 'package:katala/domain/conflict_detector.dart';
import 'package:katala/domain/nlp/nlp_pipeline.dart';
import '../../test_helpers/fake_clock.dart';
import '../../test_helpers/fake_contact_bridge.dart';
import '../../test_helpers/fake_notification_bridge.dart';

void main() {
  group('DeleteReminderUseCase & UndoDeleteReminderUseCase', () {
    late AppDatabase db;
    late ReminderRepository repository;
    late FakeNotificationBridge notificationBridge;
    late FakeClock fakeClock;
    late CreateReminderUseCase createUseCase;
    late DeleteReminderUseCase deleteUseCase;
    late UndoDeleteReminderUseCase undoUseCase;

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

      deleteUseCase = DeleteReminderUseCase(
        repository: repository,
        notificationBridge: notificationBridge,
        clock: fakeClock,
      );

      undoUseCase = UndoDeleteReminderUseCase(
        repository: repository,
        notificationBridge: notificationBridge,
        clock: fakeClock,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Soft delete marks is_deleted = 1 and cancels notification; Undo restores it', () async {
      final created = (await createUseCase.executeFromTranscript('Remind me to buy eggs tomorrow at 8am')).valueOrNull!;

      // 1. Soft delete
      final deleteResult = await deleteUseCase.execute(created.id);
      expect(deleteResult.isSuccess, isTrue);

      final inDbAfterDelete = await repository.getById(created.id);
      expect(inDbAfterDelete?.isDeleted, isTrue);
      expect(inDbAfterDelete?.deletedAt, isNotNull);

      // Notification is cancelled
      expect(await notificationBridge.getScheduledIds(), isNot(contains(created.trigger?.notificationId)));

      // 2. Undo delete
      final undoResult = await undoUseCase.execute(created.id);
      expect(undoResult.isSuccess, isTrue);

      final restoredInDb = await repository.getById(created.id);
      expect(restoredInDb?.isDeleted, isFalse);
      expect(restoredInDb?.deletedAt, isNull);

      // Notification re-scheduled
      expect(await notificationBridge.getScheduledIds(), isNotEmpty);
    });
  });
}
