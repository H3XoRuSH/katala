import 'package:drift/drift.dart';
import 'tables/action_table.dart';
import 'tables/app_metadata_table.dart';
import 'tables/reminder_table.dart';
import 'tables/trigger_table.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  ReminderTable,
  TriggerTable,
  ActionTable,
  AppMetadataTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA journal_mode=WAL;');
          await customStatement('PRAGMA foreign_keys=ON;');
          await customStatement('PRAGMA busy_timeout=3000;');
        },
        onCreate: (m) async {
          await m.createAll();

          // Create partial and performance indices per ARCHITECTURE.md §7.2
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_reminder_status ON reminder(status) WHERE is_deleted = 0;',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_reminder_parent ON reminder(parent_reminder_id);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_trigger_scheduled_time ON trigger_(scheduled_time_utc);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_trigger_notification_scheduled ON trigger_(notification_scheduled);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_trigger_delivery_status ON trigger_(delivery_status);',
          );
        },
        onUpgrade: (m, from, to) async {
          // Future schema version migrations will be added here.
        },
      );
}
