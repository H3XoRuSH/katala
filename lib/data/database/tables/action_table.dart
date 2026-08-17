import 'package:drift/drift.dart';

/// Drift definition for the `action_` table.
@DataClassName('ActionEntry')
class ActionTable extends Table {
  @override
  String get tableName => 'action_';

  TextColumn get id => text()();
  TextColumn get reminderId =>
      text().customConstraint('NOT NULL UNIQUE REFERENCES reminder(id)').named('reminder_id')();
  TextColumn get actionType => text()
      .customConstraint("NOT NULL CHECK (action_type IN ('CALL', 'TEXT', 'EMAIL', 'OPEN_URL', 'GENERAL'))")
      .named('action_type')();
  TextColumn get targetValue => text().nullable().named('target_value')();
  TextColumn get contactName => text().nullable().named('contact_name')();
  TextColumn get contactPhone => text().nullable().named('contact_phone')();
  TextColumn get contactId => text().nullable().named('contact_id')();

  @override
  Set<Column> get primaryKey => {id};
}
