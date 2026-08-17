import 'database.dart';

/// Sealed result of a SQLite database integrity verification.
sealed class IntegrityResult {
  const IntegrityResult();
}

/// The database is intact and passed all integrity checks.
final class IntegrityOk extends IntegrityResult {
  const IntegrityOk();

  @override
  String toString() => 'IntegrityOk()';
}

/// The database integrity check detected unrecoverable corruption.
final class IntegrityFailed extends IntegrityResult {
  final String details;
  const IntegrityFailed(this.details);

  @override
  String toString() => 'IntegrityFailed(details: $details)';
}

/// The database integrity check detected recoverable issues.
final class IntegrityRecoverable extends IntegrityResult {
  final String details;
  const IntegrityRecoverable(this.details);

  @override
  String toString() => 'IntegrityRecoverable(details: $details)';
}

/// Exception thrown when database corruption is detected.
class DatabaseCorruptionException implements Exception {
  final String details;
  DatabaseCorruptionException(this.details);

  @override
  String toString() => 'DatabaseCorruptionException: $details';
}

/// Runs SQLite integrity checks on startup.
class DatabaseIntegrityChecker {
  const DatabaseIntegrityChecker();

  /// Runs `PRAGMA integrity_check` and `PRAGMA quick_check` on the given database.
  Future<IntegrityResult> checkIntegrity(AppDatabase db) async {
    try {
      final integrityRows = await db.customSelect('PRAGMA integrity_check;').get();

      if (integrityRows.isEmpty) {
        return const IntegrityFailed('integrity_check returned no rows');
      }

      final firstVal = integrityRows.first.data.values.first?.toString().trim().toLowerCase();
      if (firstVal != 'ok') {
        final details = integrityRows.map((r) => r.data.values.join(':')).join('\n');
        return IntegrityFailed(details);
      }

      // Fast secondary confirmation
      final quickRows = await db.customSelect('PRAGMA quick_check;').get();
      final quickVal = quickRows.isNotEmpty ? quickRows.first.data.values.first?.toString().trim().toLowerCase() : null;
      if (quickVal != 'ok') {
        final details = quickRows.map((r) => r.data.values.join(':')).join('\n');
        return IntegrityRecoverable(details);
      }

      return const IntegrityOk();
    } catch (e) {
      return IntegrityFailed(e.toString());
    }
  }
}
