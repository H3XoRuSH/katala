import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/application/providers.dart';
import 'package:katala/data/database/database.dart';
import 'package:katala/domain/entities/reminder.dart';
import 'package:katala/platform/permissions.dart';
import 'package:katala/ui/screens/onboarding_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../test_helpers/fake_action_bridge.dart';
import '../../test_helpers/fake_contact_bridge.dart';
import '../../test_helpers/fake_notification_bridge.dart';
import '../../test_helpers/fake_permission_bridge.dart';
import '../../test_helpers/fake_speech_bridge.dart';
import '../../test_helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakePermissionBridge permissionBridge;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(createInMemoryDatabaseConnection());
    permissionBridge = FakePermissionBridge(
      microphoneStatus: PermissionStatus.denied,
      notificationStatus: PermissionStatus.denied,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        pendingRemindersStreamProvider.overrideWith((ref) => Stream.value(<Reminder>[])),
        permissionBridgeProvider.overrideWithValue(permissionBridge),
        speechBridgeProvider.overrideWithValue(FakeSpeechBridge()),
        notificationBridgeProvider.overrideWithValue(FakeNotificationBridge()),
        contactBridgeProvider.overrideWithValue(FakeContactBridge()),
        actionBridgeProvider.overrideWithValue(FakeActionBridge()),
      ],
      child: const MaterialApp(
        home: OnboardingScreen(),
      ),
    );
  }

  group('OnboardingScreen (TASK-090)', () {
    testWidgets('Pages through 3 carousel screens and completes onboarding', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Screen 1: Welcome
      expect(find.text('Katala'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);

      // Tap Get Started -> Screen 2
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(find.text('Speak Naturally'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      // Tap Next -> Screen 3: Permissions
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Permissions'), findsOneWidget);
      expect(find.text('Microphone'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      // Tap Grant on permissions
      permissionBridge.microphoneStatus = PermissionStatus.granted;
      await tester.tap(find.text('Grant').first);
      await tester.pumpAndSettle();

      // Tap Done
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(OnboardingScreen.completedKey), isTrue);
    });

    testWidgets('Skip button marks onboarding completed immediately', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Skip'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(OnboardingScreen.completedKey), isTrue);
    });
  });
}
