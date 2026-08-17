import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/app.dart';
import 'package:katala/application/providers.dart';
import 'package:katala/application/settings_provider.dart';
import 'package:katala/domain/entities/reminder.dart';
import 'package:katala/domain/entities/trigger.dart';
import 'package:katala/domain/enums/delivery_status.dart';
import 'package:katala/domain/enums/intent_type.dart';
import 'package:katala/domain/enums/reminder_status.dart';
import 'package:katala/domain/enums/trigger_type.dart';
import 'package:katala/platform/permissions.dart';
import 'package:katala/ui/screens/settings_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../test_helpers/fake_permission_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createSettingsScreen({List<Reminder>? reminders}) {
    return ProviderScope(
      overrides: [
        permissionBridgeProvider.overrideWithValue(FakePermissionBridge(
          microphoneStatus: PermissionStatus.granted,
          notificationStatus: PermissionStatus.granted,
        )),
        allRemindersStreamProvider.overrideWith(
          (ref) => Stream.value(reminders ?? []),
        ),
      ],
      child: const MaterialApp(
        home: SettingsScreen(),
      ),
    );
  }

  group('SettingsScreen (TASK-089)', () {
    testWidgets('renders all preference sections, reliability status, and about info', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('PREFERENCES'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Default Snooze Duration'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('NOTIFICATION RELIABILITY'), findsOneWidget);
      expect(find.text('PRIVACY & DATA'), findsOneWidget);
      expect(find.text('ABOUT'), findsOneWidget);
      expect(find.text('Katala'), findsOneWidget);
    });

    testWidgets('tap theme dropdown changes themeModeProvider', (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(themeModeProvider), ThemeMode.dark);
      await tester.tap(find.text('Dark').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Light').last);
      await tester.pumpAndSettle();

      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    testWidgets('tap snooze duration changes snoozeDurationProvider', (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('15 mins').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('30 mins').last);
      await tester.pumpAndSettle();

      expect(container.read(snoozeDurationProvider), 30);
    });

    testWidgets('shows privacy policy dialog when tapped', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      expect(find.text('Katala Local-First Privacy Guarantees:'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Katala Local-First Privacy Guarantees:'), findsNothing);
    });

    testWidgets('shows diagnostics dialog on long press of version info', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final now = DateTime.utc(2026, 8, 17, 10, 0);
      final reminder = Reminder(
        id: 'r1',
        title: 'Test Diagnostic Item',
        createdAt: now,
        updatedAt: now,
        status: ReminderStatus.pending,
        intentType: IntentType.general,
        trigger: Trigger(
          id: 'trig-1',
          reminderId: 'r1',
          triggerType: TriggerType.scheduledTime,
          scheduledTimeUtc: now.add(const Duration(hours: 2)),
          deliveryStatus: DeliveryStatus.scheduled,
        ),
        version: 1,
      );

      await tester.pumpWidget(createSettingsScreen(reminders: [reminder]));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Katala'));
      await tester.pumpAndSettle();

      expect(find.text('Local Diagnostics'), findsOneWidget);
      expect(find.text('• Total Reminders: 1'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Local Diagnostics'), findsNothing);
    });
  });
}
