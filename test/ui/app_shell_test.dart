import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/app.dart';
import 'package:katala/application/providers.dart';
import 'package:katala/data/database/database.dart';
import 'package:katala/domain/entities/reminder.dart';
import 'package:katala/platform/permissions.dart';
import 'package:katala/ui/widgets/mic_button.dart';
import 'package:katala/ui/widgets/text_input_field.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test_helpers/fake_action_bridge.dart';
import '../test_helpers/fake_contact_bridge.dart';
import '../test_helpers/fake_notification_bridge.dart';
import '../test_helpers/fake_permission_bridge.dart';
import '../test_helpers/fake_speech_bridge.dart';
import '../test_helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeSpeechBridge speechBridge;
  late FakeNotificationBridge notificationBridge;
  late FakeContactBridge contactBridge;
  late FakeActionBridge actionBridge;
  late FakePermissionBridge permissionBridge;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'has_completed_onboarding': true,
    });
    db = AppDatabase(createInMemoryDatabaseConnection());
    speechBridge = FakeSpeechBridge();
    notificationBridge = FakeNotificationBridge();
    contactBridge = FakeContactBridge();
    actionBridge = FakeActionBridge();
    permissionBridge = FakePermissionBridge();
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTestWidget({List<Override> extraOverrides = const []}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        pendingRemindersStreamProvider.overrideWith((ref) => Stream.value(<Reminder>[])),
        speechBridgeProvider.overrideWithValue(speechBridge),
        notificationBridgeProvider.overrideWithValue(notificationBridge),
        contactBridgeProvider.overrideWithValue(contactBridge),
        actionBridgeProvider.overrideWithValue(actionBridge),
        permissionBridgeProvider.overrideWithValue(permissionBridge),
        ...extraOverrides,
      ],
      child: const KatalaApp(),
    );
  }

  group('App Shell & Navigation (TASK-081)', () {
    testWidgets('KatalaApp launches and renders home screen when onboarding completed', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Katala'), findsOneWidget);
      expect(find.byType(TextInputField), findsOneWidget);
      expect(find.byType(MicButton), findsOneWidget);
    });

    testWidgets('KatalaApp renders onboarding screen when first launch', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        createTestWidget(
          extraOverrides: [
            isOnboardingCompletedProvider.overrideWith((ref) async => false),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('ThemeMode switch updates theme correctly', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(KatalaApp));
      final container = ProviderScope.containerOf(context);

      expect(container.read(themeModeProvider), ThemeMode.dark);

      container.read(themeModeProvider.notifier).state = ThemeMode.light;
      await tester.pumpAndSettle();

      expect(container.read(themeModeProvider), ThemeMode.light);
    });
  });
}
