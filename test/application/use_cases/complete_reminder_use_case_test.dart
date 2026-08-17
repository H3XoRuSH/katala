import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/application/use_cases/complete_reminder_use_case.dart';
import 'package:katala/application/use_cases/create_reminder_use_case.dart';
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
  group('CompleteReminderUseCase', () {
    late AppDatabase db;
    late ReminderRepository repository;
    late FakeNotificationBridge notificationBridge;
    late FakeClock fakeClock;
    late CreateReminderUseCase createUseCase;
    late CompleteReminderUseCase completeUseCase;

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

      completeUseCase = CompleteReminderUseCase(
        repository: repository,
        notificationBridge: notificationBridge,
        clock: fakeClock,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Transitions PENDING reminder to COMPLETED and cancels notification', () async {
      final created = (await createUseCase.executeFromTranscript('Remind me to read tomorrow at 10am')).valueOrNull!;

      final result = await completeUseCase.execute(created.id);
      expect(result.isSuccess, isTrue);

      final completed = await repository.getById(created.id);
      expect(completed?.status, ReminderStatus.completed);
      expect(completed?.completedAt, isNotNull);
      expect(completed?.version, 2);

      // Notification is cancelled
      expect(await notificationBridge.getScheduledIds(), isNot(contains(created.trigger?.notificationId)));
    });

    test('Already COMPLETED reminder returns InvalidStateTransition', () async {
      final created = (await createUseCase.executeFromTranscript('Remind me to read tomorrow at 10am')).valueOrNull!;
      await completeUseCase.execute(created.id);

      final secondComplete = await completeUseCase.execute(created.id);
      expect(secondComplete.isFailure, isTrue);
      expect(secondComplete.errorOrNull, isA<InvalidStateTransition>());
    });
  });
}
