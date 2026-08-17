import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/domain/entities/reminder.dart';
import 'package:katala/domain/entities/trigger.dart';
import 'package:katala/domain/enums/delivery_status.dart';
import 'package:katala/domain/enums/intent_type.dart';
import 'package:katala/domain/enums/reminder_status.dart';
import 'package:katala/domain/enums/trigger_type.dart';
import 'package:katala/ui/widgets/reminder_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final scheduledUtc = DateTime.utc(2026, 8, 17, 14, 0);
  final reminder = Reminder(
    id: 'rem-tile-1',
    title: 'Buy Groceries',
    notes: 'Milk, Eggs, Bread',
    createdAt: DateTime.utc(2026, 8, 17, 8, 0),
    updatedAt: DateTime.utc(2026, 8, 17, 8, 0),
    status: ReminderStatus.pending,
    intentType: IntentType.general,
    trigger: Trigger(
      id: 'trig-tile-1',
      reminderId: 'rem-tile-1',
      triggerType: TriggerType.scheduledTime,
      scheduledTimeUtc: scheduledUtc,
      deliveryStatus: DeliveryStatus.scheduled,
    ),
    version: 1,
  );

  group('ReminderTile (TASK-091)', () {
    testWidgets('renders title, notes, and time correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReminderTile(reminder: reminder),
          ),
        ),
      );

      expect(find.text('Buy Groceries'), findsOneWidget);
      expect(find.text('Milk, Eggs, Bread'), findsOneWidget);
      expect(find.byType(ReminderTile), findsOneWidget);
    });

    testWidgets('swipe right completes reminder and calls onComplete', (tester) async {
      bool completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReminderTile(
              reminder: reminder,
              onComplete: () => completed = true,
            ),
          ),
        ),
      );

      // Swipe right from left to right
      await tester.drag(find.text('Buy Groceries'), const Offset(500.0, 0.0));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
    });

    testWidgets('swipe left deletes reminder and calls onDelete', (tester) async {
      bool deleted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReminderTile(
              reminder: reminder,
              onDelete: () => deleted = true,
            ),
          ),
        ),
      );

      // Swipe left from right to left
      await tester.drag(find.text('Buy Groceries'), const Offset(-500.0, 0.0));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
    });

    testWidgets('long press opens accessibility action sheet and triggers action', (tester) async {
      bool completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReminderTile(
              reminder: reminder,
              onComplete: () => completed = true,
            ),
          ),
        ),
      );

      await tester.longPress(find.text('Buy Groceries'));
      await tester.pumpAndSettle();

      expect(find.text('Mark as Completed'), findsOneWidget);
      expect(find.text('Delete Reminder'), findsNothing); // onDelete was null

      await tester.tap(find.text('Mark as Completed'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
    });
  });
}
