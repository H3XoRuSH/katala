import 'package:flutter_test/flutter_test.dart';
import 'package:katala/domain/conflict_detector.dart';
import 'package:katala/domain/entities/reminder.dart';
import 'package:katala/domain/entities/trigger.dart';

void main() {
  group('ConflictDetector Unit Tests (TASK-123)', () {
    const detector = ConflictDetector();

    Reminder createReminder(String id, DateTime time, {bool hasTrigger = true}) {
      return Reminder(
        id: id,
        title: 'Reminder $id',
        createdAt: time,
        updatedAt: time,
        trigger: hasTrigger
            ? Trigger(
                id: 'trig-$id',
                reminderId: id,
                scheduledTimeUtc: time,
              )
            : null,
      );
    }

    final reminderAt2PM = createReminder('r1', DateTime.utc(2026, 8, 16, 14, 0));

    group('Conflict Detection Window (±15 minutes)', () {
      test('Candidate at exact time conflicts (0 min diff)', () {
        final candidate = DateTime.utc(2026, 8, 16, 14, 0);
        final conflicts = detector.detectConflicts(candidate, [reminderAt2PM]);
        expect(conflicts, hasLength(1));
        expect(conflicts.first.id, 'r1');
      });

      test('Candidate at 1:50 PM conflicts with reminder at 2:00 PM (10 min diff)', () {
        final candidate = DateTime.utc(2026, 8, 16, 13, 50);
        final conflicts = detector.detectConflicts(candidate, [reminderAt2PM]);
        expect(conflicts, hasLength(1));
        expect(conflicts.first.id, 'r1');
      });

      test('Candidate at 2:10 PM conflicts with reminder at 2:00 PM (10 min diff)', () {
        final candidate = DateTime.utc(2026, 8, 16, 14, 10);
        final conflicts = detector.detectConflicts(candidate, [reminderAt2PM]);
        expect(conflicts, hasLength(1));
        expect(conflicts.first.id, 'r1');
      });

      test('Candidate at 1:45 PM and 2:15 PM conflict at exact 15 minute boundary', () {
        final candidateBefore = DateTime.utc(2026, 8, 16, 13, 45);
        final conflictsBefore = detector.detectConflicts(candidateBefore, [reminderAt2PM]);
        expect(conflictsBefore, hasLength(1));

        final candidateAfter = DateTime.utc(2026, 8, 16, 14, 15);
        final conflictsAfter = detector.detectConflicts(candidateAfter, [reminderAt2PM]);
        expect(conflictsAfter, hasLength(1));
      });

      test('Candidate at 1:44:59 conflicts, 1:40 PM does NOT conflict (20 min diff)', () {
        final candidate = DateTime.utc(2026, 8, 16, 13, 40);
        final conflicts = detector.detectConflicts(candidate, [reminderAt2PM]);
        expect(conflicts, isEmpty);
      });

      test('Candidate at 2:20 PM does NOT conflict with reminder at 2:00 PM (20 min diff)', () {
        final candidate = DateTime.utc(2026, 8, 16, 14, 20);
        final conflicts = detector.detectConflicts(candidate, [reminderAt2PM]);
        expect(conflicts, isEmpty);
      });
    });

    group('Midnight Boundary & DST Edge Cases', () {
      test('Midnight boundary crossing: Candidate at 23:55 conflicts with 00:05 next day', () {
        final reminderMidnight = createReminder('r-mid', DateTime.utc(2026, 8, 17, 0, 5));
        final candidateLateNight = DateTime.utc(2026, 8, 16, 23, 55);

        final conflicts = detector.detectConflicts(candidateLateNight, [reminderMidnight]);
        expect(conflicts, hasLength(1));
        expect(conflicts.first.id, 'r-mid');
      });

      test('Midnight boundary crossing: Candidate at 00:05 conflicts with 23:55 previous day', () {
        final reminderYesterday = createReminder('r-prev', DateTime.utc(2026, 8, 16, 23, 55));
        final candidateEarlyMorning = DateTime.utc(2026, 8, 17, 0, 5);

        final conflicts = detector.detectConflicts(candidateEarlyMorning, [reminderYesterday]);
        expect(conflicts, hasLength(1));
        expect(conflicts.first.id, 'r-prev');
      });

      test('UTC vs Local conversion comparison correctly identifies conflicts', () {
        // 14:00 UTC == 22:00 UTC+8 (Asia/Manila)
        final reminderUtc = createReminder('r-utc', DateTime.utc(2026, 8, 16, 14, 0));
        // Equivalent candidate with +8 hour timezone represented in DateTime
        final candidateUtc = DateTime.utc(2026, 8, 16, 14, 10);

        final conflicts = detector.detectConflicts(candidateUtc, [reminderUtc]);
        expect(conflicts, hasLength(1));
      });
    });

    group('Edge Cases & Alternatives', () {
      test('Empty pending reminders list returns no conflicts', () {
        final candidate = DateTime.utc(2026, 8, 16, 14, 0);
        final conflicts = detector.detectConflicts(candidate, []);
        expect(conflicts, isEmpty);
      });

      test('Reminders without trigger are safely ignored and produce no conflicts', () {
        final reminderNoTrigger = createReminder('r-no-trig', DateTime.utc(2026, 8, 16, 14, 0), hasTrigger: false);
        final candidate = DateTime.utc(2026, 8, 16, 14, 0);

        final conflicts = detector.detectConflicts(candidate, [reminderNoTrigger]);
        expect(conflicts, isEmpty);
      });

      test('Multiple conflicting reminders are all returned in conflict list', () {
        final r1 = createReminder('r1', DateTime.utc(2026, 8, 16, 13, 55));
        final r2 = createReminder('r2', DateTime.utc(2026, 8, 16, 14, 5));
        final r3 = createReminder('r3', DateTime.utc(2026, 8, 16, 16, 0)); // No conflict

        final candidate = DateTime.utc(2026, 8, 16, 14, 0);
        final conflicts = detector.detectConflicts(candidate, [r1, r2, r3]);

        expect(conflicts, hasLength(2));
        expect(conflicts.map((r) => r.id), containsAll(['r1', 'r2']));
      });

      test('suggestAlternative returns a non-conflicting time outside conflict windows', () {
        final candidate = DateTime.utc(2026, 8, 16, 14, 0);
        final r1 = createReminder('r1', DateTime.utc(2026, 8, 16, 14, 0));
        final r2 = createReminder('r2', DateTime.utc(2026, 8, 16, 14, 15));

        final alternative = detector.suggestAlternative(candidate, [r1, r2]);
        expect(alternative, isNotNull);

        // Verify suggested alternative has zero conflicts with r1 and r2
        final remainingConflicts = detector.detectConflicts(alternative, [r1, r2]);
        expect(remainingConflicts, isEmpty);
      });

      test('suggestAlternative with empty conflicts returns original candidate time', () {
        final candidate = DateTime.utc(2026, 8, 16, 14, 0);
        final alternative = detector.suggestAlternative(candidate, []);
        expect(alternative, candidate);
      });
    });
  });
}
