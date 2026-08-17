import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/domain/entities/reminder.dart';
import 'package:katala/domain/entities/trigger.dart';
import 'package:katala/domain/enums/delivery_status.dart';
import 'package:katala/domain/enums/intent_type.dart';
import 'package:katala/domain/enums/reminder_status.dart';
import 'package:katala/domain/enums/trigger_type.dart';
import 'package:katala/ui/screens/settings_screen.dart';
import 'package:katala/ui/widgets/empty_state.dart';
import 'package:katala/ui/widgets/recovery_screen.dart';
import 'package:katala/ui/widgets/reminder_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Accessibility Audit Pass (TASK-093)', () {
    testWidgets('ReminderTile meets minimum 48dp height and has Semantics label', (tester) async {
      final reminder = Reminder(
        id: 'acc-1',
        title: 'Accessibility Check',
        notes: 'Screen reader test',
        createdAt: DateTime.utc(2026, 8, 17, 9, 0),
        updatedAt: DateTime.utc(2026, 8, 17, 9, 0),
        status: ReminderStatus.pending,
        intentType: IntentType.general,
        trigger: Trigger(
          id: 'trig-acc-1',
          reminderId: 'acc-1',
          triggerType: TriggerType.scheduledTime,
          scheduledTimeUtc: DateTime.utc(2026, 8, 17, 15, 0),
          deliveryStatus: DeliveryStatus.scheduled,
        ),
        version: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReminderTile(reminder: reminder),
          ),
        ),
      );

      final tileFinder = find.byType(ReminderTile);
      expect(tileFinder, findsOneWidget);

      final renderBox = tester.renderObject<RenderBox>(tileFinder);
      expect(renderBox.size.height, greaterThanOrEqualTo(48.0));

      final semantics = tester.getSemantics(tileFinder);
      expect(semantics.label.contains('Accessibility Check'), isTrue);
      expect(semantics.flagsCollection.isButton, isTrue);
    });

    testWidgets('EmptyTimelineState and AllCaughtUpState contain semantic descriptions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyTimelineState(),
          ),
        ),
      );

      final emptySemantics = tester.getSemantics(find.byType(EmptyTimelineState));
      expect(emptySemantics.label.contains('No reminders yet'), isTrue);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AllCaughtUpState(),
          ),
        ),
      );

      final caughtUpSemantics = tester.getSemantics(find.byType(AllCaughtUpState));
      expect(caughtUpSemantics.label.contains('All caught up!'), isTrue);
    });

    testWidgets('RecoveryScreen action buttons meet 48dp minimum touch target height', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RecoveryScreen(),
        ),
      );

      final restoreBtn = find.byType(FilledButton);
      final resetBtn = find.byType(OutlinedButton);

      final restoreBox = tester.renderObject<RenderBox>(restoreBtn);
      final resetBox = tester.renderObject<RenderBox>(resetBtn);

      expect(restoreBox.size.height, greaterThanOrEqualTo(48.0));
      expect(resetBox.size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('SettingsScreen list items and tiles render with accessible labels', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PREFERENCES'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Default Snooze Duration'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('NOTIFICATION RELIABILITY'), findsOneWidget);
      expect(find.text('PRIVACY & DATA'), findsOneWidget);
    });
  });
}
