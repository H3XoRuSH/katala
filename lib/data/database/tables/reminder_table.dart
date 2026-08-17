import 'package:drift/drift.dart';

/// Drift definition for the `reminder` table.
@DataClassName('ReminderEntry')
class ReminderTable extends Table {
  @override
  String get tableName => 'reminder';

  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get intentType => text()
      .customConstraint("NOT NULL CHECK (intent_type IN ('GENERAL', 'CALL', 'TEXT', 'EMAIL', 'OPEN_URL'))")
      .named('intent_type')();
  TextColumn get status => text()
      .customConstraint("NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'COMPLETED', 'SNOOZED', 'DISMISSED'))")
      .named('status')();
  IntColumn get snoozeCount => integer().customConstraint('NOT NULL DEFAULT 0').named('snooze_count')();
  IntColumn get snoozeDurationMinutes =>
      integer().customConstraint('NOT NULL DEFAULT 10').named('snooze_duration_minutes')();
  TextColumn get parentReminderId =>
      text().nullable().customConstraint('REFERENCES reminder(id)').named('parent_reminder_id')();
  IntColumn get depth => integer().customConstraint('NOT NULL DEFAULT 0')();
  IntColumn get version => integer().customConstraint('NOT NULL DEFAULT 1')();
  TextColumn get originalTranscript => text().nullable().named('original_transcript')();
  TextColumn get createdAt => text().named('created_at')();
  TextColumn get updatedAt => text().named('updated_at')();
  TextColumn get completedAt => text().nullable().named('completed_at')();
  IntColumn get isDeleted => integer().customConstraint('NOT NULL DEFAULT 0').named('is_deleted')();
  TextColumn get deletedAt => text().nullable().named('deleted_at')();

  @override
  Set<Column> get primaryKey => {id};
}
