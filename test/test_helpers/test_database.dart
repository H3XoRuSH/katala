import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// Creates an in-memory database connection for repository and DAO unit tests.
DatabaseConnection createInMemoryDatabaseConnection() {
  return DatabaseConnection(NativeDatabase.memory());
}
