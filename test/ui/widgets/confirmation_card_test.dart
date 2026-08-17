import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/application/use_cases/create_reminder_use_case.dart';
import 'package:katala/data/database/database.dart';
import 'package:katala/data/repositories/reminder_repository_impl.dart';
import 'package:katala/domain/conflict_detector.dart';
import 'package:katala/domain/entities/parsed_reminder.dart';
import 'package:katala/domain/entities/reminder.dart';
import 'package:katala/domain/enums/intent_type.dart';
import 'package:katala/domain/nlp/clock.dart';
import 'package:katala/domain/nlp/nlp_pipeline.dart';
import 'package:katala/ui/widgets/confirmation_card.dart';
import '../../test_helpers/fake_clock.dart';
import '../../test_helpers/fake_contact_bridge.dart';
import '../../test_helpers/fake_notification_bridge.dart';
import '../../test_helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ReminderRepositoryImpl repo;
  late FakeNotificationBridge fakeNotif;
  late FakeContactBridge fakeContact;
  late Clock fakeClock;
  late CreateReminderUseCase createUseCase;

  setUp(() {
    db = AppDatabase(createInMemoryDatabaseConnection());
    repo = ReminderRepositoryImpl(db);
    fakeNotif = FakeNotificationBridge();
    fakeContact = FakeContactBridge();
    fakeClock = FakeClock(DateTime.utc(2026, 8, 17, 10, 0));
    createUseCase = CreateReminderUseCase(
      nlpPipeline: const NlpPipeline(),
      contactBridge: fakeContact,
      conflictDetector: const ConflictDetector(),
      repository: repo,
      notificationBridge: fakeNotif,
      clock: fakeClock,
    );
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('ConfirmationCard displays parsed fields and saves reminder on tap Save', (tester) async {
    Reminder? savedResult;

    final parsed = ParsedReminder(
      title: 'Call Dr. Smith',
      scheduledTime: DateTime.utc(2026, 8, 17, 15, 0),
      intentType: IntentType.call,
      contactName: 'Dr. Smith',
      phoneNumber: '+15551234567',
      notes: 'Check prescription',
      originalTranscript: 'Call Dr. Smith at 3pm to check prescription',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConfirmationCard(
            parsed: parsed,
            createReminderUseCase: createUseCase,
            onSaveSuccess: (rem) {
              savedResult = rem;
            },
          ),
        ),
      ),
    );

    // Verify fields displayed
    expect(find.text('Confirm Reminder'), findsOneWidget);
    expect(find.byKey(const Key('confirmation_title_text')), findsOneWidget);
    expect(find.text('Call Dr. Smith'), findsOneWidget);
    expect(find.text('Check prescription'), findsOneWidget);

    // Tap Save
    await tester.ensureVisible(find.byKey(const Key('confirmation_save_button')));
    await tester.tap(find.byKey(const Key('confirmation_save_button')));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(savedResult, isNotNull);
    expect(savedResult!.title, equals('Call Dr. Smith'));
  });

  testWidgets('ConfirmationCard supports inline editing mode', (tester) async {
    final parsed = ParsedReminder(
      title: 'Initial Title',
      scheduledTime: DateTime.utc(2026, 8, 17, 15, 0),
      intentType: IntentType.general,
      originalTranscript: 'Initial Title at 3pm',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConfirmationCard(
            parsed: parsed,
            createReminderUseCase: createUseCase,
          ),
        ),
      ),
    );

    // Tap edit button
    await tester.tap(find.byKey(const Key('confirmation_edit_button')));
    await tester.pump();

    expect(find.text('Edit Reminder'), findsOneWidget);
    expect(find.byKey(const Key('confirmation_title_edit_input')), findsOneWidget);

    // Modify title
    await tester.enterText(find.byKey(const Key('confirmation_title_edit_input')), 'Updated Title');
    await tester.tap(find.text('Apply Edits'));
    await tester.pump();

    expect(find.text('Updated Title'), findsOneWidget);
  });
}
