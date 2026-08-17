import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/app.dart';
import 'package:katala/application/providers.dart';
import 'package:katala/data/database/database.dart';
import 'package:katala/domain/entities/reminder.dart';
import 'package:katala/platform/permissions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_helpers/fake_action_bridge.dart';
import 'test_helpers/fake_clock.dart';
import 'test_helpers/fake_contact_bridge.dart';
import 'test_helpers/fake_notification_bridge.dart';
import 'test_helpers/fake_permission_bridge.dart';
import 'test_helpers/fake_speech_bridge.dart';
import 'test_helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({'has_completed_onboarding': true});
    db = AppDatabase(createInMemoryDatabaseConnection());
  });

  tearDown(() async {
    await db.close();
  });

  group('Scaffold & Test Infrastructure', () {
    testWidgets('KatalaApp builds successfully', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            pendingRemindersStreamProvider.overrideWith((ref) => Stream.value(<Reminder>[])),
            permissionBridgeProvider.overrideWithValue(FakePermissionBridge()),
            speechBridgeProvider.overrideWithValue(FakeSpeechBridge()),
            notificationBridgeProvider.overrideWithValue(FakeNotificationBridge()),
            contactBridgeProvider.overrideWithValue(FakeContactBridge()),
            actionBridgeProvider.overrideWithValue(FakeActionBridge()),
          ],
          child: const KatalaApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Katala'), findsOneWidget);
    });

    test('FakeClock correctly manages and advances time', () {
      final initial = DateTime.utc(2026, 8, 16, 10, 0);
      final clock = FakeClock(initial, timezone: 'Asia/Manila');

      expect(clock.now(), initial);
      expect(clock.localTimezone(), 'Asia/Manila');

      clock.advance(const Duration(minutes: 30));
      expect(clock.now(), DateTime.utc(2026, 8, 16, 10, 30));
    });
  });
}
