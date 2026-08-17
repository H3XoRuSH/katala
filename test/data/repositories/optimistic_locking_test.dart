import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/data/database/database.dart';
import 'package:katala/data/repositories/reminder_repository.dart';
import 'package:katala/data/repositories/reminder_repository_impl.dart';
import 'package:katala/domain/entities/validated_reminder.dart';
import 'package:katala/domain/enums/reminder_status.dart';

void main() {
  group('Optimistic Locking & Concurrency', () {
    late AppDatabase db;
    late ReminderRepository repo1;
    late ReminderRepository repo2;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo1 = ReminderRepositoryImpl(db);
      repo2 = ReminderRepositoryImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('transitionState returns 1 on matching version and 0 on stale version', () async {
      final reminder = await repo1.insert(
        ValidatedReminder(
          title: 'Concurrency Test',
          scheduledTime: DateTime.utc(2026, 8, 16, 14, 0),
          originalTranscript: 'concurrency',
        ),
      );

      expect(reminder.version, 1);

      // First transition with version 1 -> succeeds
      final affected1 = await repo1.transitionState(reminder.id, 1, ReminderStatus.snoozed);
      expect(affected1, 1);

      // Verify version in DB is now 2
      final updated = await repo1.getById(reminder.id);
      expect(updated?.version, 2);
      expect(updated?.status, ReminderStatus.snoozed);

      // Stale attempt with old version 1 -> returns 0 affected rows
      final affected2 = await repo2.transitionState(reminder.id, 1, ReminderStatus.completed);
      expect(affected2, 0);
    });

    test('update() auto-retries once by re-reading state on version collision', () async {
      final initial = await repo1.insert(
        ValidatedReminder(
          title: 'Initial Title',
          scheduledTime: DateTime.utc(2026, 8, 16, 14, 0),
          originalTranscript: 'initial',
        ),
      );

      // Read from repo2 at version 1
      final copyFromRepo2 = await repo2.getById(initial.id);
      expect(copyFromRepo2?.version, 1);

      // repo1 transitions state -> bumps version to 2
      await repo1.transitionState(initial.id, 1, ReminderStatus.snoozed);

      // repo2 tries to update with old version 1 -> retry logic re-reads version 2 and succeeds
      final updatedByRepo2 = await repo2.update(
        copyFromRepo2!.copyWith(title: 'Updated from Repo 2'),
        expectedVersion: 1,
      );

      expect(updatedByRepo2.version, 3);
      expect(updatedByRepo2.title, 'Updated from Repo 2');

      final finalDoc = await repo1.getById(initial.id);
      expect(finalDoc?.title, 'Updated from Repo 2');
      expect(finalDoc?.version, 3);
    });

    test('softDelete throws OptimisticLockException when expected version does not match', () async {
      final reminder = await repo1.insert(
        ValidatedReminder(
          title: 'Delete test',
          scheduledTime: DateTime.utc(2026, 8, 16, 14, 0),
          originalTranscript: 'delete',
        ),
      );

      // Bump version to 2
      await repo1.transitionState(reminder.id, 1, ReminderStatus.snoozed);

      // Try to delete with stale version 1 -> throws OptimisticLockException
      expect(
        () => repo2.softDelete(reminder.id, 1),
        throwsA(isA<OptimisticLockException>()),
      );
    });
  });
}
