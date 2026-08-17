import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/application/use_cases/complete_reminder_use_case.dart';
import 'package:katala/application/use_cases/create_reminder_use_case.dart';
import 'package:katala/application/use_cases/delete_reminder_use_case.dart';
import 'package:katala/application/use_cases/reconcile_notifications_use_case.dart';
import 'package:katala/application/use_cases/snooze_reminder_use_case.dart';
import 'package:katala/data/database/database.dart';
import 'package:katala/data/repositories/reminder_repository.dart';
import 'package:katala/data/repositories/reminder_repository_impl.dart';
import 'package:katala/domain/conflict_detector.dart';
import 'package:katala/domain/enums/reminder_status.dart';
import 'package:katala/domain/nlp/nlp_pipeline.dart';
import '../test_helpers/fake_clock.dart';
import '../test_helpers/fake_contact_bridge.dart';
import '../test_helpers/fake_notification_bridge.dart';

void main() {
  group('TASK-111 & TASK-112: Notification ID Mapping, Lifecycle & Duplicate Prevention', () {
    late AppDatabase db;
    late ReminderRepository repository;
    late FakeNotificationBridge notificationBridge;
    late FakeClock fakeClock;
    late CreateReminderUseCase createUseCase;
    late CompleteReminderUseCase completeUseCase;
    late SnoozeReminderUseCase snoozeUseCase;
    late DeleteReminderUseCase deleteUseCase;
    late ReconcileNotificationsUseCase reconcileUseCase;

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

      snoozeUseCase = SnoozeReminderUseCase(
        repository: repository,
        notificationBridge: notificationBridge,
        clock: fakeClock,
      );

      deleteUseCase = DeleteReminderUseCase(
        repository: repository,
        notificationBridge: notificationBridge,
        clock: fakeClock,
      );

      reconcileUseCase = ReconcileNotificationsUseCase(
        repository: repository,
        notificationBridge: notificationBridge,
        clock: fakeClock,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Lifecycle: schedule -> verify ID stored -> cancel -> verify ID cleared -> reschedule -> new ID', () async {
      // 1. Schedule initial reminder
      final r1 = (await createUseCase.executeFromTranscript('Dentist appointment tomorrow at 10am')).valueOrNull!;
      final initialNotifId = r1.trigger?.notificationId;
      expect(initialNotifId, isNotNull);
      expect(r1.trigger?.notificationScheduled, isTrue);
      expect(notificationBridge.scheduledNotifications.containsKey(initialNotifId), isTrue);

      // 2. Complete reminder (cancels notification and clears DB notification_id)
      await completeUseCase.execute(r1.id);
      final completed = await repository.getById(r1.id);
      expect(completed?.status, equals(ReminderStatus.completed));
      expect(completed?.trigger?.notificationScheduled, isFalse);
      expect(notificationBridge.scheduledNotifications.containsKey(initialNotifId), isFalse);
      expect(notificationBridge.cancelledNotificationIds, contains(initialNotifId));

      // 3. Create another reminder and snooze it
      final r2 = (await createUseCase.executeFromTranscript('Team standup tomorrow at 9am')).valueOrNull!;
      final r2FirstNotifId = r2.trigger?.notificationId;
      expect(r2FirstNotifId, isNotNull);

      // Snooze r2
      final snoozedResult = await snoozeUseCase.execute(r2.id, customDurationMinutes: 15);
      expect(snoozedResult.isSuccess, isTrue);

      final snoozed = await repository.getById(r2.id);
      final r2SecondNotifId = snoozed?.trigger?.notificationId;
      expect(r2SecondNotifId, isNotNull);
      expect(r2SecondNotifId, isNot(equals(r2FirstNotifId)));
      // Old ID cancelled from bridge
      expect(notificationBridge.cancelledNotificationIds, contains(r2FirstNotifId));
      // New ID active in bridge
      expect(notificationBridge.scheduledNotifications.containsKey(r2SecondNotifId), isTrue);
    });

    test('Stale cleanup: Reconciliation cancels notifications for COMPLETED, DISMISSED, and soft-deleted reminders',
        () async {
      // Create 3 reminders
      final r1 = (await createUseCase.executeFromTranscript('Task 1 tomorrow at 10am')).valueOrNull!;
      final r2 = (await createUseCase.executeFromTranscript('Task 2 tomorrow at 11am')).valueOrNull!;
      final r3 = (await createUseCase.executeFromTranscript('Task 3 tomorrow at 12pm')).valueOrNull!;

      final id1 = r1.trigger!.notificationId!;
      final id2 = r2.trigger!.notificationId!;
      final id3 = r3.trigger!.notificationId!;

      // Mark r1 as completed in DB directly (simulating stale OS notification left behind)
      await repository.transitionState(r1.id, r1.version, ReminderStatus.completed);
      // Mark r2 as dismissed in DB directly
      await repository.transitionState(r2.id, r2.version, ReminderStatus.dismissed);
      // Mark r3 as soft-deleted
      await deleteUseCase.execute(r3.id);
      expect(notificationBridge.cancelledNotificationIds, contains(id3));

      // Ensure notificationBridge still holds id1 and id2 as simulated stale notifications
      expect(notificationBridge.scheduledNotifications.containsKey(id1), isTrue);
      expect(notificationBridge.scheduledNotifications.containsKey(id2), isTrue);

      // Run reconciliation
      final result = await reconcileUseCase.execute();

      expect(result.cancelledIds, contains(id1));
      expect(result.cancelledIds, contains(id2));
      expect(notificationBridge.scheduledNotifications.containsKey(id1), isFalse);
      expect(notificationBridge.scheduledNotifications.containsKey(id2), isFalse);
    });

    test('Duplicate prevention: Scheduling an already-scheduled reminder cancels old notification first', () async {
      final r1 = (await createUseCase.executeFromTranscript('Daily review tomorrow at 6pm')).valueOrNull!;
      final firstNotifId = r1.trigger!.notificationId!;

      // Clear the trigger scheduled state in DB to simulate unscheduled DB flag while OS still holds notification
      await repository.updateTriggerScheduling(r1.id, false, firstNotifId);

      // Run reconciliation - it should cancel old firstNotifId before scheduling a new ID
      final result = await reconcileUseCase.execute();
      expect(result.scheduledIds, contains(r1.id));

      final updated = await repository.getById(r1.id);
      final newNotifId = updated!.trigger!.notificationId!;
      expect(newNotifId, isNot(equals(firstNotifId)));
      expect(notificationBridge.cancelledNotificationIds, contains(firstNotifId));
      expect(notificationBridge.scheduledNotifications.containsKey(newNotifId), isTrue);
    });
  });
}
