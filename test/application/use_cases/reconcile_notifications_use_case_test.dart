import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/application/use_cases/create_reminder_use_case.dart';
import 'package:katala/application/use_cases/reconcile_notifications_use_case.dart';
import 'package:katala/data/database/database.dart';
import 'package:katala/data/repositories/reminder_repository.dart';
import 'package:katala/data/repositories/reminder_repository_impl.dart';
import 'package:katala/domain/conflict_detector.dart';
import 'package:katala/domain/enums/delivery_status.dart';
import 'package:katala/domain/enums/reminder_status.dart';
import 'package:katala/domain/nlp/nlp_pipeline.dart';
import '../../test_helpers/fake_clock.dart';
import '../../test_helpers/fake_contact_bridge.dart';
import '../../test_helpers/fake_notification_bridge.dart';

void main() {
  group('ReconcileNotificationsUseCase Integration', () {
    late AppDatabase db;
    late ReminderRepository repository;
    late FakeNotificationBridge notificationBridge;
    late FakeClock fakeClock;
    late CreateReminderUseCase createUseCase;
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

      reconcileUseCase = ReconcileNotificationsUseCase(
        repository: repository,
        notificationBridge: notificationBridge,
        clock: fakeClock,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Reconciliation cancels orphaned OS notifications and schedules missing ones', () async {
      // 1. Create reminder 1 & 2
      final r1 = (await createUseCase.executeFromTranscript('Remind me to do task 1 tomorrow at 10am')).valueOrNull!;
      final r2 = (await createUseCase.executeFromTranscript('Remind me to do task 2 tomorrow at 2pm')).valueOrNull!;

      // Mark r1 as completed in DB, but leave its notification in notificationBridge (simulated mismatch)
      await repository.transitionState(r1.id, r1.version, ReminderStatus.completed);

      // Unschedule r2 in notificationBridge (simulated missed schedule)
      final r2NotifId = r2.trigger!.notificationId!;
      notificationBridge.scheduledNotifications.remove(r2NotifId);
      await repository.updateTriggerScheduling(r2.id, false, null);

      // Add a ghost notification ID in notificationBridge that does not exist in DB
      notificationBridge.scheduledNotifications[9999] = r1.copyWith(id: 'ghost-id');

      // Run reconciliation
      final result = await reconcileUseCase.execute();

      // Ghost & completed r1 notification should be cancelled
      expect(result.cancelledIds, contains(9999));
      expect(result.cancelledIds, contains(r1.trigger?.notificationId));

      // r2 should be newly scheduled
      expect(result.scheduledIds, contains(r2.id));

      // Verify metadata last_reconciled_at is updated
      final lastReconciled = await repository.getMetadata('last_reconciled_at');
      expect(lastReconciled, isNotNull);
      expect(DateTime.parse(lastReconciled!), equals(fakeClock.now().toUtc()));
    });

    test('Reconciliation is idempotent (running twice produces identical state)', () async {
      await createUseCase.executeFromTranscript('Remind me to do task 1 tomorrow at 10am');
      await createUseCase.executeFromTranscript('Remind me to do task 2 tomorrow at 2pm');

      final firstPass = await reconcileUseCase.execute();
      expect(firstPass.cancelledIds, isEmpty);

      final secondPass = await reconcileUseCase.execute();
      expect(secondPass.cancelledIds, isEmpty);
      expect(secondPass.scheduledIds, isEmpty);
    });

    test('TASK-113: First reconciliation (null last_reconciled_at) skips missed detection and sets timestamp',
        () async {
      // Create past reminder before first reconciliation
      final pastTime = fakeClock.now().subtract(const Duration(hours: 2));
      final r1 = (await createUseCase.executeFromTranscript('Task in the past tomorrow at 10am')).valueOrNull!;
      // Update scheduled time to past
      final trigger = await repository.findTriggerByReminderId(r1.id);
      await repository.update(
        r1.copyWith(trigger: trigger!.copyWith(scheduledTimeUtc: pastTime)),
        expectedVersion: r1.version,
      );

      expect(await repository.getMetadata('last_reconciled_at'), isNull);

      // Execute first reconciliation
      await reconcileUseCase.execute();

      // Timestamp should now be set
      final meta = await repository.getMetadata('last_reconciled_at');
      expect(meta, isNotNull);

      // Trigger delivery status should NOT be set to deliveryUncertain on first reconciliation
      final updated = await repository.getById(r1.id);
      expect(updated?.trigger?.deliveryStatus, equals(DeliveryStatus.scheduled));
    });

    test('TASK-113: Subsequent reconciliation detects reminders in time gap and sets delivery_uncertain', () async {
      final t0 = fakeClock.now();
      // Set last_reconciled_at to t0
      await repository.setMetadata('last_reconciled_at', t0.toUtc().toIso8601String());

      // Create reminder scheduled at t0 + 2 hours
      final scheduledTime = t0.add(const Duration(hours: 2));
      final r1 = (await createUseCase.executeFromTranscript('Task in gap tomorrow at 10am')).valueOrNull!;
      final trigger = await repository.findTriggerByReminderId(r1.id);
      await repository.update(
        r1.copyWith(trigger: trigger!.copyWith(scheduledTimeUtc: scheduledTime)),
        expectedVersion: r1.version,
      );

      // Advance clock by 4 hours (now = t0 + 4 hours)
      fakeClock.advance(const Duration(hours: 4));

      // Run reconciliation
      await reconcileUseCase.execute();

      // Reminder was scheduled in gap (t0 to t0+4h) and not fired -> delivery_uncertain
      final updated = await repository.getById(r1.id);
      expect(updated?.trigger?.deliveryStatus, equals(DeliveryStatus.deliveryUncertain));

      // Metadata updated to current time
      final meta = await repository.getMetadata('last_reconciled_at');
      expect(DateTime.parse(meta!), equals(fakeClock.now().toUtc()));
    });

    test('Overdue reminder with notificationScheduled=false is not re-scheduled during reconciliation', () async {
      // 1. Create reminder in past
      final pastTime = fakeClock.now().subtract(const Duration(hours: 3));
      final r1 = (await createUseCase.executeFromTranscript('Overdue task yesterday at 10am')).valueOrNull!;
      final trigger = await repository.findTriggerByReminderId(r1.id);
      await repository.update(
        r1.copyWith(
          trigger: trigger!.copyWith(
            scheduledTimeUtc: pastTime,
            notificationScheduled: false,
            notificationId: null,
          ),
        ),
        expectedVersion: r1.version,
      );

      // Notification bridge does not contain r1
      if (r1.trigger?.notificationId != null) {
        await notificationBridge.cancel(r1.trigger!.notificationId!);
      }
      expect(await notificationBridge.getScheduledIds(), isNot(contains(r1.trigger?.notificationId)));

      // 2. Reconcile
      final result = await reconcileUseCase.execute();

      // r1 should NOT be scheduled
      expect(result.scheduledIds, isNot(contains(r1.id)));
      expect(await notificationBridge.getScheduledIds(), isEmpty);
    });

    test('Reminder within 2m grace window is scheduled if never fired, skipped if already fired', () async {
      // 1. Unfired reminder 60 seconds overdue
      final recentPastTime = fakeClock.now().subtract(const Duration(seconds: 60));
      final r1 = (await createUseCase.executeFromTranscript('Task 1 tomorrow at 10am')).valueOrNull!;
      final trigger1 = await repository.findTriggerByReminderId(r1.id);
      await repository.update(
        r1.copyWith(
          trigger: trigger1!.copyWith(
            scheduledTimeUtc: recentPastTime,
            notificationScheduled: false,
            notificationId: null,
            firedAt: null,
          ),
        ),
        expectedVersion: r1.version,
      );
      await notificationBridge.cancelForReminder(r1.id);

      // 2. Already fired reminder 60 seconds overdue
      final r2 = (await createUseCase.executeFromTranscript('Task 2 tomorrow at 2pm')).valueOrNull!;
      final trigger2 = await repository.findTriggerByReminderId(r2.id);
      await repository.update(
        r2.copyWith(
          trigger: trigger2!.copyWith(
            scheduledTimeUtc: recentPastTime,
            notificationScheduled: false,
            notificationId: null,
            firedAt: recentPastTime,
          ),
        ),
        expectedVersion: r2.version,
      );
      await notificationBridge.cancelForReminder(r2.id);

      // Run reconciliation
      final result = await reconcileUseCase.execute();

      // r1 (unfired) is scheduled within 2m grace window
      expect(result.scheduledIds, contains(r1.id));
      // r2 (already fired) is NOT scheduled
      expect(result.scheduledIds, isNot(contains(r2.id)));
    });
  });
}
