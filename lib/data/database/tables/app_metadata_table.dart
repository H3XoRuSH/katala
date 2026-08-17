import 'package:drift/drift.dart';

/// Drift definition for the `app_metadata` key-value table.
@DataClassName('AppMetadataEntry')
class AppMetadataTable extends Table {
  @override
  String get tableName => 'app_metadata';

  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
