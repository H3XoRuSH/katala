import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/data/database/database.dart';
import 'package:katala/data/repositories/reminder_repository.dart';
import 'package:katala/data/repositories/reminder_repository_impl.dart';
import 'package:katala/domain/entities/resolved_contact.dart';
import 'package:katala/domain/entities/validated_reminder.dart';
import 'package:katala/domain/enums/action_type.dart';
import 'package:katala/domain/enums/delivery_status.dart';
import 'package:katala/domain/enums/intent_type.dart';
import 'package:katala/domain/enums/reminder_status.dart';

void main() {
  group('ReminderRepositoryImpl', () {
    late AppDatabase db;
    late ReminderRepository repository;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repository = ReminderRepositoryImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('insert() creates reminder, trigger, and action in a single transaction', () async {
      final scheduledTime = DateTime.utc(2026, 8, 17, 10, 0);
      const contact = ResolvedContact(
        platformId: 'c-1',
        displayName: 'Adam Smith',
        phoneNumber: '+639171234567',
      );

      final validated = ValidatedReminder(
        title: 'Call Adam',
        resolvedContact: contact,
        phoneNumber: '+639171234567',
        notes: 'Discuss project katala',
        scheduledTime: scheduledTime,
        timezone: 'Asia/Manila',
        intentType: IntentType.call,
        originalTranscript: 'Call Adam tomorrow at 10am',
      );

      final inserted = await repository.insert(validated);

      expect(inserted.id, isNotEmpty);
      expect(inserted.title, 'Call Adam');
      expect(inserted.intentType, IntentType.call);
      expect(inserted.status, ReminderStatus.pending);
      expect(inserted.version, 1);
      expect(inserted.trigger, isNotNull);
      expect(inserted.trigger?.scheduledTimeUtc, scheduledTime);
      expect(inserted.trigger?.scheduledTimeTimezone, 'Asia/Manila');
      expect(inserted.action, isNotNull);
      expect(inserted.action?.actionType, ActionType.call);
      expect(inserted.action?.contactName, 'Adam Smith');
      expect(inserted.action?.contactPhone, '+639171234567');

      // Verify retrieval by ID
      final retrieved = await repository.getById(inserted.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.id, inserted.id);
      expect(retrieved.title, inserted.title);
      expect(retrieved.action?.contactName, 'Adam Smith');
    });

    test('getPending() returns pending and snoozed reminders, excluding soft-deleted', () async {
      final now = DateTime.utc(2026, 8, 16, 12, 0);

      final r1 = await repository.insert(
        ValidatedReminder(
          title: 'Pending reminder 1',
          scheduledTime: now.add(const Duration(hours: 1)),
          originalTranscript: 'r1',
        ),
      );

      final r2 = await repository.insert(
        ValidatedReminder(
          title: 'Pending reminder 2',
          scheduledTime: now.add(const Duration(hours: 2)),
          originalTranscript: 'r2',
        ),
      );

      // Transition r2 to SNOOZED
      await repository.transitionState(r2.id, r2.version, ReminderStatus.snoozed);

      // Create r3 and complete it
      final r3 = await repository.insert(
        ValidatedReminder(
          title: 'Completed reminder',
          scheduledTime: now.add(const Duration(hours: 3)),
          originalTranscript: 'r3',
        ),
      );
      await repository.transitionState(r3.id, r3.version, ReminderStatus.completed);

      // Create r4 and soft-delete it
      final r4 = await repository.insert(
        ValidatedReminder(
          title: 'Deleted reminder',
          scheduledTime: now.add(const Duration(hours: 4)),
          originalTranscript: 'r4',
        ),
      );
      await repository.softDelete(r4.id, r4.version);

      final pending = await repository.getPending();
      expect(pending, hasLength(2));
      expect(pending.map((r) => r.id), containsAll([r1.id, r2.id]));
      expect(pending.map((r) => r.id), isNot(contains(r3.id)));
      expect(pending.map((r) => r.id), isNot(contains(r4.id)));
    });

    test('getOverdue() returns overdue pending reminders', () async {
      final now = DateTime.utc(2026, 8, 16, 12, 0);

      final past = await repository.insert(
        ValidatedReminder(
          title: 'Past reminder',
          scheduledTime: now.subtract(const Duration(hours: 2)),
          originalTranscript: 'past',
        ),
      );

      final future = await repository.insert(
        ValidatedReminder(
          title: 'Future reminder',
          scheduledTime: now.add(const Duration(hours: 2)),
          originalTranscript: 'future',
        ),
      );

      final overdue = await repository.getOverdue(now);
      expect(overdue, hasLength(1));
      expect(overdue.first.id, past.id);
      expect(overdue.map((r) => r.id), isNot(contains(future.id)));
    });

    test('getByTimeRange() queries reminders within boundary', () async {
      final start = DateTime.utc(2026, 8, 16, 10, 0);
      final end = DateTime.utc(2026, 8, 16, 14, 0);

      final inside = await repository.insert(
        ValidatedReminder(
          title: 'Inside range',
          scheduledTime: DateTime.utc(2026, 8, 16, 12, 0),
          originalTranscript: 'inside',
        ),
      );

      await repository.insert(
        ValidatedReminder(
          title: 'Outside range',
          scheduledTime: DateTime.utc(2026, 8, 16, 18, 0),
          originalTranscript: 'outside',
        ),
      );

      final inRange = await repository.getByTimeRange(start, end);
      expect(inRange, hasLength(1));
      expect(inRange.first.id, inside.id);
    });

    test('getConflicting() detects reminders within ±15 minutes', () async {
      final candidate = DateTime.utc(2026, 8, 16, 14, 0);

      final conflicting = await repository.insert(
        ValidatedReminder(
          title: 'Conflicting reminder',
          scheduledTime: DateTime.utc(2026, 8, 16, 14, 10),
          originalTranscript: 'conflicting',
        ),
      );

      await repository.insert(
        ValidatedReminder(
          title: 'Non-conflicting reminder',
          scheduledTime: DateTime.utc(2026, 8, 16, 15, 0),
          originalTranscript: 'non-conflicting',
        ),
      );

      final conflicts = await repository.getConflicting(candidate);
      expect(conflicts, hasLength(1));
      expect(conflicts.first.id, conflicting.id);
    });

    test('updateTriggerScheduling, deliveryStatus, and firedAt persist correctly', () async {
      final r = await repository.insert(
        ValidatedReminder(
          title: 'Trigger update test',
          scheduledTime: DateTime.utc(2026, 8, 16, 14, 0),
          originalTranscript: 'trigger test',
        ),
      );

      await repository.updateTriggerScheduling(r.id, true, 101);
      var trigger = await repository.findTriggerByReminderId(r.id);
      expect(trigger?.notificationScheduled, isTrue);
      expect(trigger?.notificationId, 101);

      await repository.updateTriggerDeliveryStatus(r.id, DeliveryStatus.deliveryUncertain);
      trigger = await repository.findTriggerByReminderId(r.id);
      expect(trigger?.deliveryStatus, DeliveryStatus.deliveryUncertain);

      final firedTime = DateTime.utc(2026, 8, 16, 14, 0, 1);
      await repository.updateTriggerFiredAt(r.id, firedTime);
      trigger = await repository.findTriggerByReminderId(r.id);
      expect(trigger?.firedAt, firedTime);
    });

    test('Metadata key-value storage works and is updated on conflict', () async {
      expect(await repository.getMetadata('last_reconciled_at'), isNull);

      await repository.setMetadata('last_reconciled_at', '2026-08-16T12:00:00Z');
      expect(await repository.getMetadata('last_reconciled_at'), '2026-08-16T12:00:00Z');

      await repository.setMetadata('last_reconciled_at', '2026-08-16T14:00:00Z');
      expect(await repository.getMetadata('last_reconciled_at'), '2026-08-16T14:00:00Z');
    });

    test('watchPending stream emits when reminders are added or changed', () async {
      final initial = await repository.watchPending().first;
      expect(initial, isEmpty);

      await repository.insert(
        ValidatedReminder(
          title: 'Stream test',
          scheduledTime: DateTime.utc(2026, 8, 16, 14, 0),
          originalTranscript: 'stream',
        ),
      );

      final updated = await repository.watchPending().first;
      expect(updated, hasLength(1));
    });
  });
}
