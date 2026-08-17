import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:katala/domain/entities/reminder.dart';
import 'package:katala/domain/entities/trigger.dart';
import 'package:katala/domain/enums/intent_type.dart';
import 'package:katala/domain/enums/reminder_status.dart';
import 'package:katala/ui/widgets/conflict_warning.dart';

void main() {
  final testNow = DateTime.utc(2026, 8, 17, 10, 0);
  final conflict1 = Reminder(
    id: 'rem-1',
    title: 'Dentist appointment',
    status: ReminderStatus.pending,
    intentType: IntentType.general,
    createdAt: testNow,
    updatedAt: testNow,
    trigger: Trigger(
      id: 'trig-1',
      reminderId: 'rem-1',
      scheduledTimeUtc: DateTime.utc(2026, 8, 17, 10, 10),
    ),
  );

  testWidgets('ConflictWarning renders conflicting reminder info and alternative slot', (tester) async {
    bool savedAnyway = false;
    DateTime? movedTo;
    bool cancelled = false;

    final alternative = DateTime.utc(2026, 8, 17, 10, 45);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConflictWarning(
            conflictingReminders: [conflict1],
            suggestedAlternative: alternative,
            onSaveAnyway: () {
              savedAnyway = true;
            },
            onMoveToAlternative: (newTime) {
              movedTo = newTime;
            },
            onCancel: () {
              cancelled = true;
            },
          ),
        ),
      ),
    );

    // Verify title and conflict message
    expect(find.text('Schedule Conflict'), findsOneWidget);
    expect(find.textContaining('Dentist appointment'), findsWidgets);
    expect(find.text('Save Anyway'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Tap Move to Alternative
    final formattedAlternative = DateFormat('h:mm a').format(alternative.toLocal());
    final moveBtn = find.widgetWithText(ElevatedButton, 'Move to $formattedAlternative');
    expect(moveBtn, findsOneWidget);
    await tester.tap(moveBtn);
    await tester.pump();
    expect(movedTo, equals(alternative));

    // Tap Save Anyway
    await tester.tap(find.text('Save Anyway'));
    await tester.pump();
    expect(savedAnyway, isTrue);

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(cancelled, isTrue);
  });
}
