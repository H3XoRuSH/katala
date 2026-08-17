import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/domain/entities/parsed_reminder.dart';
import 'package:katala/domain/enums/intent_type.dart';
import 'package:katala/domain/enums/validation_issue.dart';
import 'package:katala/ui/widgets/clarification_card.dart';

void main() {
  testWidgets('ClarificationCard handles missingTime with quick-pick chips', (tester) async {
    ParsedReminder? savedResult;

    const draft = ParsedReminder(
      title: 'Buy milk',
      intentType: IntentType.general,
      issues: [ValidationIssue.missingTime],
      originalTranscript: 'remind me to buy milk',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClarificationCard(
            initialDraft: draft,
            onSave: (result) {
              savedResult = result;
            },
            onCancel: () {},
          ),
        ),
      ),
    );

    expect(find.text('Clarification Needed'), findsOneWidget);
    expect(find.text('When should I remind you?'), findsOneWidget);
    expect(find.byKey(const Key('chip_later_today')), findsOneWidget);
    expect(find.byKey(const Key('chip_tomorrow_9am')), findsOneWidget);

    // Save should initially be disabled because time is missing
    final saveButton = tester.widget<ElevatedButton>(find.byKey(const Key('clarification_save_button')));
    expect(saveButton.onPressed, isNull);

    // Tap quick chip
    await tester.tap(find.byKey(const Key('chip_tomorrow_9am')));
    await tester.pump();

    // Now save button is enabled
    final updatedSaveButton = tester.widget<ElevatedButton>(find.byKey(const Key('clarification_save_button')));
    expect(updatedSaveButton.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('clarification_save_button')));
    await tester.pump();

    expect(savedResult, isNotNull);
    expect(savedResult!.title, equals('Buy milk'));
    expect(savedResult!.scheduledTime, isNotNull);
  });

  testWidgets('ClarificationCard handles ambiguousTime with AM/PM selection', (tester) async {
    final draft = ParsedReminder(
      title: 'Team sync',
      scheduledTime: DateTime.now().add(const Duration(hours: 2)),
      intentType: IntentType.general,
      issues: [ValidationIssue.ambiguousTime],
      originalTranscript: 'sync at 9',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClarificationCard(
            initialDraft: draft,
            onSave: (_) {},
            onCancel: () {},
          ),
        ),
      ),
    );

    expect(find.text('Did you mean AM or PM?'), findsOneWidget);
    expect(find.byKey(const Key('am_choice_chip')), findsOneWidget);
    expect(find.byKey(const Key('pm_choice_chip')), findsOneWidget);

    await tester.tap(find.byKey(const Key('pm_choice_chip')));
    await tester.pump();
  });

  testWidgets('ClarificationCard handles missingTitle and timeInPast', (tester) async {
    ParsedReminder? savedResult;

    final pastTime = DateTime.now().subtract(const Duration(hours: 2));
    final draft = ParsedReminder(
      scheduledTime: pastTime,
      intentType: IntentType.general,
      issues: [ValidationIssue.missingTitle, ValidationIssue.timeInPast],
      originalTranscript: 'remind me at 8am',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClarificationCard(
            initialDraft: draft,
            onSave: (res) {
              savedResult = res;
            },
            onCancel: () {},
          ),
        ),
      ),
    );

    expect(find.text('What should I remind you about?'), findsOneWidget);
    expect(find.text('That time has passed. Pick a future time.'), findsOneWidget);

    // Enter title
    await tester.enterText(find.byKey(const Key('clarification_title_input')), 'Doctor visit');
    await tester.pump();

    // Select future time chip
    await tester.tap(find.byKey(const Key('chip_tomorrow_9am')));
    await tester.pump();

    // Tap save
    await tester.tap(find.byKey(const Key('clarification_save_button')));
    await tester.pump();

    expect(savedResult, isNotNull);
    expect(savedResult!.title, equals('Doctor visit'));
    expect(savedResult!.scheduledTime!.isAfter(DateTime.now()), isTrue);
  });
}
