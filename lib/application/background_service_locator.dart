import 'dart:io';
import 'package:drift/native.dart';
import '../data/database/database.dart';
import '../data/repositories/reminder_repository.dart';
import '../data/repositories/reminder_repository_impl.dart';
import '../domain/nlp/clock.dart';
import '../platform/bridges/action_bridge.dart';
import '../platform/bridges/notification_bridge.dart';

/// Static thread-safe service locator for background isolates and notification action callbacks.
///
/// Strictly independent of Flutter widget trees, WidgetsBinding, and Riverpod.
class BackgroundServiceLocator {
  static AppDatabase? _db;
  static ReminderRepository? _reminderRepo;
  static NotificationBridge? _notificationBridge;
  static ActionBridge? _actionBridge;
  static Clock _clock = const SystemClock();
  static bool _initialized = false;

  BackgroundServiceLocator._();

  /// Initializes the background service locator.
  static Future<void> initialize({
    AppDatabase? database,
    String? databasePath,
    required NotificationBridge notificationBridge,
    required ActionBridge actionBridge,
    Clock clock = const SystemClock(),
  }) async {
    if (_initialized) return;

    if (database != null) {
      _db = database;
    } else if (databasePath != null) {
      _db = AppDatabase(NativeDatabase(File(databasePath)));
    } else {
      throw ArgumentError('Either database or databasePath must be provided.');
    }

    _reminderRepo = ReminderRepositoryImpl(_db!);
    _notificationBridge = notificationBridge;
    _actionBridge = actionBridge;
    _clock = clock;
    _initialized = true;
  }

  static bool get isInitialized => _initialized;

  static void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('BackgroundServiceLocator is not initialized. Call initialize() first.');
    }
  }

  static AppDatabase get database {
    _ensureInitialized();
    return _db!;
  }

  static ReminderRepository get reminderRepo {
    _ensureInitialized();
    return _reminderRepo!;
  }

  static NotificationBridge get notificationBridge {
    _ensureInitialized();
    return _notificationBridge!;
  }

  static ActionBridge get actionBridge {
    _ensureInitialized();
    return _actionBridge!;
  }

  static Clock get clock => _clock;

  /// Disposes background services and closes the database instance.
  static Future<void> dispose() async {
    await _db?.close();
    _db = null;
    _reminderRepo = null;
    _notificationBridge = null;
    _actionBridge = null;
    _clock = const SystemClock();
    _initialized = false;
  }
}
