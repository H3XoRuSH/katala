import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/data/database/database.dart';
import 'package:katala/data/database/integrity_checker.dart';

void main() {
  group('DatabaseIntegrityChecker', () {
    late AppDatabase db;
    const checker = DatabaseIntegrityChecker();

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('checkIntegrity returns IntegrityOk on a clean database', () async {
      final result = await checker.checkIntegrity(db);
      expect(result, isA<IntegrityOk>());
    });
  });
}
