import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'application/providers.dart';
import 'data/database/database.dart';
import 'data/database/integrity_checker.dart';
import 'platform/bridges/method_channel_notification_bridge.dart';

/// App entrypoint running foreground startup sequence (TASK-081).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize database
  final db = AppDatabase(driftDatabase(name: 'katala'));

  // 2. Startup integrity check
  const checker = DatabaseIntegrityChecker();
  final integrity = await checker.checkIntegrity(db);
  if (integrity is IntegrityFailed) {
    debugPrint('Database integrity failure: ${integrity.details}');
  }

  // 3. Configure OS notification channels and sounds
  final notifBridge = MethodChannelNotificationBridge();
  await notifBridge.configureCategories();

  // 4. ProviderScope with database override
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
      child: const KatalaApp(),
    ),
  );
}
