import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/domain/entities/reminder.dart';
import 'package:katala/domain/entities/trigger.dart';
import 'package:katala/domain/enums/delivery_status.dart';
import 'package:katala/domain/enums/intent_type.dart';
import 'package:katala/ui/theme/theme.dart';
import 'package:katala/ui/widgets/reliability_banner.dart';
import 'package:katala/ui/widgets/reminder_tile.dart';
import 'package:katala/ui/widgets/timeline_group.dart';

void main() {
  final now = DateTime.utc(2026, 8, 16, 12, 0);

  final testReminder1 = Reminder(
    id: 'rem-1',
    title: 'Call Adam',
    intentType: IntentType.call,
    createdAt: now,
    updatedAt: now,
    trigger: Trigger(
      id: 'trig-1',
      reminderId: 'rem-1',
      scheduledTimeUtc: now.add(const Duration(hours: 2)),
    ),
  );

  final testReminder2 = Reminder(
    id: 'rem-2',
    title: 'Check document',
    intentType: IntentType.openUrl,
    createdAt: now,
    updatedAt: now,
    trigger: Trigger(
      id: 'trig-2',
      reminderId: 'rem-2',
      scheduledTimeUtc: now.add(const Duration(hours: 4)),
      deliveryStatus: DeliveryStatus.deliveryUncertain,
    ),
  );

  group('TimelineGroup & ReminderTile Widgets (TASK-082)', () {
    testWidgets('TimelineGroup renders title, badge count, and items', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: TimelineGroup(
              title: 'Today',
              reminders: [testReminder1, testReminder2],
            ),
          ),
        ),
      );

      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Call Adam'), findsOneWidget);
      expect(find.text('Check document'), findsOneWidget);
    });

    testWidgets('TimelineGroup collapses and expands on tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: TimelineGroup(
              title: 'Today',
              reminders: [testReminder1],
              initialExpanded: true,
            ),
          ),
        ),
      );

      expect(find.text('Call Adam'), findsOneWidget);

      // Tap header to collapse
      await tester.tap(find.text('TODAY'));
      await tester.pumpAndSettle();

      expect(find.text('Call Adam'), findsNothing);

      // Tap header to expand
      await tester.tap(find.text('TODAY'));
      await tester.pumpAndSettle();

      expect(find.text('Call Adam'), findsOneWidget);
    });

    testWidgets('ReminderTile swipe right triggers onComplete', (tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: ReminderTile(
              reminder: testReminder1,
              onComplete: () => completed = true,
            ),
          ),
        ),
      );

      expect(find.text('Call Adam'), findsOneWidget);

      // Fling right
      await tester.fling(find.byType(Dismissible), const Offset(500, 0), 1000);
      await tester.pumpAndSettle();

      expect(completed, isTrue);
    });

    testWidgets('ReminderTile swipe left triggers onDelete', (tester) async {
      bool deleted = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: ReminderTile(
              reminder: testReminder1,
              onDelete: () => deleted = true,
            ),
          ),
        ),
      );

      // Fling left
      await tester.fling(find.byType(Dismissible), const Offset(-500, 0), 1000);
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
    });

    testWidgets('ReliabilityBanner renders when uncertain count > 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: ReliabilityBanner(uncertainCount: 3),
          ),
        ),
      );

      expect(find.text('Delivery Uncertain'), findsOneWidget);
      expect(find.text('3 reminders may have been missed or delayed.'), findsOneWidget);
    });
  });
}
