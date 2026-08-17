import 'package:flutter_test/flutter_test.dart';
import 'package:katala/domain/entities/reminder.dart';
import 'package:katala/domain/enums/reminder_status.dart';
import 'package:katala/domain/errors.dart';
import 'package:katala/domain/state_machine.dart';

void main() {
  group('Reminder State Machine (TASK-123)', () {
    late Reminder basePending;
    late Reminder baseSnoozed;
    final testTime = DateTime.utc(2026, 8, 16, 15, 0);

    setUp(() {
      basePending = Reminder(
        id: 'rem-1',
        title: 'Buy groceries',
        status: ReminderStatus.pending,
        snoozeCount: 0,
        version: 1,
        createdAt: DateTime.utc(2026, 8, 16, 12, 0),
        updatedAt: DateTime.utc(2026, 8, 16, 12, 0),
      );

      baseSnoozed = Reminder(
        id: 'rem-2',
        title: 'Call doctor',
        status: ReminderStatus.snoozed,
        snoozeCount: 1,
        version: 2,
        createdAt: DateTime.utc(2026, 8, 16, 12, 0),
        updatedAt: DateTime.utc(2026, 8, 16, 12, 10),
      );
    });

    group('Valid State Transitions & Version Increments', () {
      test('1. PENDING -> COMPLETED succeeds, sets completedAt, updatedAt and increments version', () {
        final res = transition(basePending, ReminderStatus.completed, now: testTime);
        expect(res.isSuccess, isTrue);
        final updated = res.valueOrNull!;
        expect(updated.status, ReminderStatus.completed);
        expect(updated.version, basePending.version + 1);
        expect(updated.completedAt, testTime);
        expect(updated.updatedAt, testTime);
      });

      test('2. PENDING -> SNOOZED succeeds, increments snoozeCount, updatedAt and version', () {
        final res = transition(basePending, ReminderStatus.snoozed, now: testTime);
        expect(res.isSuccess, isTrue);
        final updated = res.valueOrNull!;
        expect(updated.status, ReminderStatus.snoozed);
        expect(updated.snoozeCount, 1);
        expect(updated.version, basePending.version + 1);
        expect(updated.updatedAt, testTime);
      });

      test('3. PENDING -> DISMISSED succeeds, sets updatedAt and increments version', () {
        final res = transition(basePending, ReminderStatus.dismissed, now: testTime);
        expect(res.isSuccess, isTrue);
        final updated = res.valueOrNull!;
        expect(updated.status, ReminderStatus.dismissed);
        expect(updated.version, basePending.version + 1);
        expect(updated.updatedAt, testTime);
      });

      test('4. SNOOZED -> PENDING succeeds on timer expiry, preserves snoozeCount and increments version', () {
        final res = transition(baseSnoozed, ReminderStatus.pending, now: testTime);
        expect(res.isSuccess, isTrue);
        final updated = res.valueOrNull!;
        expect(updated.status, ReminderStatus.pending);
        expect(updated.version, baseSnoozed.version + 1);
        expect(updated.snoozeCount, 1); // Preserves previous snooze count
        expect(updated.updatedAt, testTime);
      });

      test('5. SNOOZED -> SNOOZED succeeds, increments snoozeCount, updatedAt and version', () {
        final res = transition(baseSnoozed, ReminderStatus.snoozed, now: testTime);
        expect(res.isSuccess, isTrue);
        final updated = res.valueOrNull!;
        expect(updated.status, ReminderStatus.snoozed);
        expect(updated.snoozeCount, 2);
        expect(updated.version, baseSnoozed.version + 1);
        expect(updated.updatedAt, testTime);
      });

      test('6. SNOOZED -> COMPLETED succeeds, sets completedAt, updatedAt and increments version', () {
        final res = transition(baseSnoozed, ReminderStatus.completed, now: testTime);
        expect(res.isSuccess, isTrue);
        final updated = res.valueOrNull!;
        expect(updated.status, ReminderStatus.completed);
        expect(updated.version, baseSnoozed.version + 1);
        expect(updated.completedAt, testTime);
        expect(updated.updatedAt, testTime);
      });

      test('7. SNOOZED -> DISMISSED succeeds, sets updatedAt and increments version', () {
        final res = transition(baseSnoozed, ReminderStatus.dismissed, now: testTime);
        expect(res.isSuccess, isTrue);
        final updated = res.valueOrNull!;
        expect(updated.status, ReminderStatus.dismissed);
        expect(updated.version, baseSnoozed.version + 1);
        expect(updated.updatedAt, testTime);
      });
    });

    group('Guard Conditions & Limits', () {
      test('Guard: allows snoozing up to 10 times (snoozeCount 0 to 9 -> 10)', () {
        var current = basePending;
        for (int i = 0; i < 10; i++) {
          final res = transition(current, ReminderStatus.snoozed, now: testTime);
          expect(res.isSuccess, isTrue, reason: 'Failed at snooze iteration $i');
          current = res.valueOrNull!;
          expect(current.snoozeCount, i + 1);
        }

        expect(current.snoozeCount, 10);

        // 11th snooze attempt must fail
        final eleventhAttempt = transition(current, ReminderStatus.snoozed, now: testTime);
        expect(eleventhAttempt.isFailure, isTrue);
        expect(eleventhAttempt.errorOrNull, isA<InvalidStateTransition>());
      });

      test('Guard: snooze_count < 10 blocks 11th snooze attempt from PENDING or SNOOZED', () {
        final maxSnoozedPending = basePending.copyWith(snoozeCount: 10);
        final res1 = transition(maxSnoozedPending, ReminderStatus.snoozed, now: testTime);
        expect(res1.isFailure, isTrue);
        expect(res1.errorOrNull, isA<InvalidStateTransition>());

        final maxSnoozed = baseSnoozed.copyWith(snoozeCount: 10);
        final res2 = transition(maxSnoozed, ReminderStatus.snoozed, now: testTime);
        expect(res2.isFailure, isTrue);
        expect(res2.errorOrNull, isA<InvalidStateTransition>());
      });
    });

    group('Terminal States & Invalid Transitions', () {
      test('Terminal state: COMPLETED rejects all transition attempts', () {
        final completed = basePending.copyWith(status: ReminderStatus.completed);

        for (final target in ReminderStatus.values) {
          final res = transition(completed, target, now: testTime);
          expect(res.isFailure, isTrue, reason: 'COMPLETED should not transition to $target');
          expect(res.errorOrNull, isA<InvalidStateTransition>());
        }
      });

      test('Terminal state: DISMISSED rejects all transition attempts', () {
        final dismissed = basePending.copyWith(status: ReminderStatus.dismissed);

        for (final target in ReminderStatus.values) {
          final res = transition(dismissed, target, now: testTime);
          expect(res.isFailure, isTrue, reason: 'DISMISSED should not transition to $target');
          expect(res.errorOrNull, isA<InvalidStateTransition>());
        }
      });

      test('Invalid direct transition: PENDING -> PENDING is rejected', () {
        final res = transition(basePending, ReminderStatus.pending, now: testTime);
        expect(res.isFailure, isTrue);
        expect(res.errorOrNull, isA<InvalidStateTransition>());
      });
    });

    group('Optimistic Concurrency Simulation', () {
      test('Optimistic concurrency simulation: separate transitions increment version cleanly', () {
        final res1 = transition(basePending, ReminderStatus.completed, now: testTime);
        final res2 = transition(basePending, ReminderStatus.dismissed, now: testTime);

        expect(res1.valueOrNull!.version, basePending.version + 1);
        expect(res2.valueOrNull!.version, basePending.version + 1);
      });
    });
  });
}
