import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/application/background_service_locator.dart';
import 'package:katala/data/database/database.dart';
import '../test_helpers/fake_action_bridge.dart';
import '../test_helpers/fake_clock.dart';
import '../test_helpers/fake_notification_bridge.dart';

void main() {
  group('BackgroundServiceLocator Integration', () {
    tearDown(() async {
      if (BackgroundServiceLocator.isInitialized) {
        await BackgroundServiceLocator.dispose();
      }
    });

    test('Throws StateError if accessed before initialization', () {
      expect(() => BackgroundServiceLocator.database, throwsStateError);
      expect(() => BackgroundServiceLocator.reminderRepo, throwsStateError);
      expect(() => BackgroundServiceLocator.notificationBridge, throwsStateError);
      expect(() => BackgroundServiceLocator.actionBridge, throwsStateError);
    });

    test('Initializes with in-memory database and exposes services cleanly', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final notifBridge = FakeNotificationBridge();
      final actionBridge = FakeActionBridge();
      final clock = FakeClock(DateTime.utc(2026, 8, 17, 10, 0));

      await BackgroundServiceLocator.initialize(
        database: db,
        notificationBridge: notifBridge,
        actionBridge: actionBridge,
        clock: clock,
      );

      expect(BackgroundServiceLocator.isInitialized, isTrue);
      expect(BackgroundServiceLocator.database, equals(db));
      expect(BackgroundServiceLocator.notificationBridge, equals(notifBridge));
      expect(BackgroundServiceLocator.actionBridge, equals(actionBridge));
      expect(BackgroundServiceLocator.clock, equals(clock));

      await BackgroundServiceLocator.dispose();
      expect(BackgroundServiceLocator.isInitialized, isFalse);
    });
  });
}
