import 'package:drift/drift.dart';

/// Drift definition for the `trigger_` table.
@DataClassName('TriggerEntry')
class TriggerTable extends Table {
  @override
  String get tableName => 'trigger_';

  TextColumn get id => text()();
  TextColumn get reminderId =>
      text().customConstraint('NOT NULL UNIQUE REFERENCES reminder(id)').named('reminder_id')();
  TextColumn get triggerType => text()
      .customConstraint("NOT NULL CHECK (trigger_type IN ('SCHEDULED_TIME', 'GEOFENCE'))")
      .named('trigger_type')();
  TextColumn get scheduledTimeUtc => text().named('scheduled_time_utc')();
  TextColumn get scheduledTimeTimezone =>
      text().customConstraint("NOT NULL DEFAULT 'UTC'").named('scheduled_time_timezone')();
  IntColumn get notificationScheduled =>
      integer().customConstraint('NOT NULL DEFAULT 0').named('notification_scheduled')();
  IntColumn get notificationId => integer().nullable().named('notification_id')();
  TextColumn get firedAt => text().nullable().named('fired_at')();
  TextColumn get deliveryStatus => text()
      .customConstraint(
          "NOT NULL DEFAULT 'scheduled' CHECK (delivery_status IN ('scheduled', 'delivery_uncertain', 'delivery_missed'))")
      .named('delivery_status')();
  TextColumn get recurrenceRule => text().nullable().named('recurrence_rule')();

  @override
  Set<Column> get primaryKey => {id};
}
