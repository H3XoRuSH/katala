import 'package:flutter_test/flutter_test.dart';
import 'package:katala/application/use_cases/complete_reminder_use_case.dart';
import 'package:katala/application/use_cases/edit_reminder_use_case.dart';
import 'package:katala/application/use_cases/snooze_reminder_use_case.dart';
import 'package:katala/data/database/database.dart';
import 'package:katala/data/repositories/reminder_repository.dart';
import 'package:katala/data/repositories/reminder_repository_impl.dart';
import 'package:katala/domain/entities/reminder.dart';
import 'package:katala/domain/entities/trigger.dart';
import 'package:katala/domain/enums/intent_type.dart';
import 'package:katala/domain/enums/reminder_status.dart';
import 'package:katala/domain/enums/trigger_type.dart';
import 'package:katala/domain/errors.dart';
import '../test_helpers/fake_clock.dart';
import '../test_helpers/fake_notification_bridge.dart';
import '../test_helpers/test_database.dart';

void main() {
  group('Concurrent Modification & Optimistic Concurrency Integration (TASK-121)', () {
    late AppDatabase db;
    late ReminderRepositoryImpl repository;
    late FakeNotificationBridge notificationBridge;
    late FakeClock clock;
    late CompleteReminderUseCase completeUseCase;
    late SnoozeReminderUseCase snoozeUseCase;
    late EditReminderUseCase editUseCase;

    final now = DateTime.utc(2026, 8, 17, 10, 0);

    setUp(() {
      db = AppDatabase(createInMemoryDatabaseConnection());
      repository = ReminderRepositoryImpl(db);
      notificationBridge = FakeNotificationBridge();
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

      editUseCase = EditReminderUseCase(
        repository: repository,
        notificationBridge: notificationBridge,
        clock: clock,
      );
    });

    tearDown(() async {
      await db.close();
    });

    Future<Reminder> insertInitialReminder({required String id, required String title}) async {
      final reminder = Reminder(
        id: id,
        title: title,
        status: ReminderStatus.pending,
        intentType: IntentType.general,
        snoozeCount: 0,
        version: 1,
        createdAt: now,
        updatedAt: now,
      );
      final trigger = Trigger(
        id: 'trig-$id',
        reminderId: id,
        triggerType: TriggerType.scheduledTime,
        scheduledTimeUtc: now.add(const Duration(hours: 2)),
      );
      return repository.insertRaw(reminder, trigger, null);
    }

    test('Optimistic locking: softDelete with stale expectedVersion throws OptimisticLockException', () async {
      final initial = await insertInitialReminder(id: 'rem-conflict-1', title: 'Buy milk');
      expect(initial.version, 1);

      // Client A advances version to 2 via state transition
      final rowsAffected = await repository.transitionState(
        initial.id,
        1,
        ReminderStatus.completed,
      );
      expect(rowsAffected, 1);

      // Client B attempts soft delete using stale version 1
      expect(
        repository.softDelete(initial.id, 1),
        throwsA(isA<OptimisticLockException>()),
      );

      // Soft delete with current expectedVersion 2 succeeds
      await repository.softDelete(initial.id, 2);
      final deleted = await repository.getById(initial.id);
      expect(deleted?.isDeleted, isTrue);
      expect(deleted?.version, 3);
    });

    test('Optimistic locking: transitionState with stale version returns 0 affected rows', () async {
      final initial = await insertInitialReminder(id: 'rem-trans-1', title: 'Pick up laundry');

      // First transition succeeds (version 1 -> 2)
      final affected1 = await repository.transitionState(initial.id, 1, ReminderStatus.snoozed);
      expect(affected1, 1);

      // Stale transition with version 1 fails and affects 0 rows
      final affectedStale = await repository.transitionState(initial.id, 1, ReminderStatus.completed);
      expect(affectedStale, 0);

      // Fresh transition with version 2 succeeds
      final affectedFresh = await repository.transitionState(initial.id, 2, ReminderStatus.completed);
      expect(affectedFresh, 1);
    });

    test('Simultaneous use case operations: Complete vs Snooze race condition', () async {
      final initial = await insertInitialReminder(id: 'rem-race-1', title: 'Submit report');

      // Background action completes reminder
      final completeResult = await completeUseCase.execute(initial.id);
      expect(completeResult.isSuccess, isTrue);

      // UI/Notification snooze attempted after state transition to completed
      final snoozeResult = await snoozeUseCase.execute(initial.id);
      // Because state is now COMPLETED, state machine transition guard blocks snooze
      expect(snoozeResult.isFailure, isTrue);
      expect(snoozeResult.errorOrNull, isA<InvalidStateTransition>());
    });

    test('Simultaneous Edit vs State Transition: reloads and updates version', () async {
      final initial = await insertInitialReminder(id: 'rem-race-2', title: 'Dentist appointment');

      // Snooze updates version from 1 to 2
      final snoozeResult = await snoozeUseCase.execute(initial.id);
      expect(snoozeResult.isSuccess, isTrue);

      // Fetch fresh entity and update successfully
      final fresh = await repository.getById(initial.id);
      expect(fresh, isNotNull);
      final prevVersion = fresh!.version;

      final editResult = await editUseCase.execute(fresh.copyWith(title: 'Dentist moved to 11am'));
      expect(editResult.isSuccess, isTrue);
      expect(editResult.valueOrNull?.title, 'Dentist moved to 11am');
      expect(editResult.valueOrNull?.version, prevVersion + 1);
    });
  });
}
