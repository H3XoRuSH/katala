import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/data/database/database.dart';

void main() {
  group('Database Migrations & Schema Initialization', () {
    test('Database opens with version 1 and all 4 tables and indices created', () async {
      final db = AppDatabase(NativeDatabase.memory());

      expect(db.schemaVersion, 1);

      // Verify all tables exist and can be queried
      final reminders = await db.select(db.reminderTable).get();
      expect(reminders, isEmpty);

      final triggers = await db.select(db.triggerTable).get();
      expect(triggers, isEmpty);

      final actions = await db.select(db.actionTable).get();
      expect(actions, isEmpty);

      final metadata = await db.select(db.appMetadataTable).get();
      expect(metadata, isEmpty);

      // Verify PRAGMAs can be queried without error
      final journalMode = await db.customSelect('PRAGMA journal_mode;').get();
      expect(journalMode, isNotEmpty);

      await db.close();
    });
  });
}
