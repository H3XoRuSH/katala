import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/app.dart';
import 'package:katala/application/providers.dart';
import 'package:katala/data/database/database.dart';
import 'package:katala/domain/entities/resolved_contact.dart';
import 'package:katala/domain/enums/speech_availability.dart';
import 'package:katala/platform/permissions.dart';
import 'package:katala/ui/screens/home_screen.dart';
import 'package:katala/ui/widgets/clarification_card.dart';
import 'package:katala/ui/widgets/confirmation_card.dart';
import 'package:katala/ui/widgets/conflict_warning.dart';
import 'package:katala/ui/widgets/mic_button.dart';
import 'package:katala/ui/widgets/reminder_tile.dart';
import 'package:katala/ui/widgets/text_input_field.dart';
import 'package:katala/ui/widgets/voice_input_overlay.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test_helpers/fake_action_bridge.dart';
import '../test_helpers/fake_clock.dart';
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
  late FakeClock clock;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'has_completed_onboarding': true,
    });
    db = AppDatabase(createInMemoryDatabaseConnection());
    clock = FakeClock(DateTime.utc(2026, 8, 17, 10, 0)); // Monday 10:00 AM UTC
    speechBridge = FakeSpeechBridge(
      mockAvailability: SpeechAvailability.available,
      mockOnDeviceAvailable: true,
      transcriptsToEmit: ['Remind me to buy groceries tomorrow at 10am'],
    );
    notificationBridge = FakeNotificationBridge();
    contactBridge = FakeContactBridge([
      const ResolvedContact(
        platformId: 'c1',
        displayName: 'Sarah',
        phoneNumber: '+1234567890',
        allPhoneNumbers: ['+1234567890'],
      ),
    ]);
    actionBridge = FakeActionBridge();
    permissionBridge = FakePermissionBridge(
      microphoneStatus: PermissionStatus.granted,
      notificationStatus: PermissionStatus.granted,
      contactsStatus: PermissionStatus.granted,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestApp({List<Override> extraOverrides = const []}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
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

  Future<void> cleanupTester(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  group('TASK-100: End-to-End Voice-to-Persist Integration', () {
    testWidgets(
      'Full Voice Flow: Mic Tap -> VoiceOverlay Live Stream -> Stop -> ConfirmationCard -> Save -> Database & Notification & Timeline',
      (tester) async {
        final stopwatch = Stopwatch()..start();

        // 1. Launch Katala App
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(MicButton), findsOneWidget);

        // 2. Tap Mic Button
        await tester.tap(find.byType(MicButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verify VoiceInputOverlay opened and speech listening started
        expect(find.byType(VoiceInputOverlay), findsOneWidget);
        expect(find.text('Remind me to buy groceries tomorrow at 10am'), findsOneWidget);

        // 3. Tap Stop button on VoiceInputOverlay
        await tester.tap(find.byKey(const Key('stop_listening_button')));
        await tester.pumpAndSettle();

        // 4. Verification: ConfirmationCard appears with parsed title
        expect(find.byType(ConfirmationCard), findsOneWidget);
        expect(find.byKey(const Key('confirmation_title_text')), findsOneWidget);
        expect(find.text('buy groceries'), findsOneWidget);

        // 5. Tap "Save Reminder" button
        await tester.tap(find.byKey(const Key('confirmation_save_button')));
        await tester.pumpAndSettle();

        stopwatch.stop();

        // Verify performance target: < 5 seconds total flow
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));

        // 6. Verify Reminder persisted in Database
        final allInDb = await db.select(db.reminderTable).get();
        expect(allInDb.length, equals(1));
        final saved = allInDb.first;
        expect(saved.title, equals('buy groceries'));
        expect(saved.status, equals('PENDING'));

        // 7. Verify Notification scheduled via NotificationBridge
        expect(notificationBridge.scheduledNotifications.length, equals(1));
        expect(notificationBridge.scheduledNotifications.values.first.id, equals(saved.id));

        // 8. Verify Timeline UI reactively displays the new reminder
        expect(find.byType(ReminderTile), findsOneWidget);
        expect(find.text('buy groceries'), findsOneWidget);

        await cleanupTester(tester);
      },
    );

    testWidgets(
      'Voice Flow with Missing Time: Mic Tap -> VoiceOverlay -> ClarificationCard -> Pick Quick Time -> Save -> Database & Notification',
      (tester) async {
        // Speech input without explicit time
        speechBridge.transcriptsToEmit = ['Buy milk'];

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Tap Mic
        await tester.tap(find.byType(MicButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(VoiceInputOverlay), findsOneWidget);
        expect(find.text('Buy milk'), findsOneWidget);

        // Tap Stop
        await tester.tap(find.byKey(const Key('stop_listening_button')));
        await tester.pumpAndSettle();

        // Since time was missing, ClarificationCard should appear
        expect(find.byType(ClarificationCard), findsOneWidget);
        expect(find.text('Clarification Needed'), findsOneWidget);

        // Tap quick chip "chip_tomorrow_9am"
        await tester.tap(find.byKey(const Key('chip_tomorrow_9am')));
        await tester.pump();

        // Tap Save on ClarificationCard
        await tester.tap(find.byKey(const Key('clarification_save_button')));
        await tester.pumpAndSettle();

        // Now ConfirmationCard is shown
        expect(find.byType(ConfirmationCard), findsOneWidget);

        // Tap Save on ConfirmationCard
        await tester.tap(find.byKey(const Key('confirmation_save_button')));
        await tester.pumpAndSettle();

        // Verify saved to DB and scheduled
        final allInDb = await db.select(db.reminderTable).get();
        expect(allInDb.length, equals(1));
        expect(allInDb.first.title.toLowerCase(), contains('buy milk'));
        expect(notificationBridge.scheduledNotifications.length, equals(1));

        // Verify rendered in timeline
        expect(find.byType(ReminderTile), findsOneWidget);

        await cleanupTester(tester);
      },
    );

    testWidgets(
      'Voice Flow with Contact Action: "Call Sarah tomorrow at 3pm" -> Saved with Call Action',
      (tester) async {
        speechBridge.transcriptsToEmit = ['Call Sarah tomorrow at 3pm'];

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Tap Mic
        await tester.tap(find.byType(MicButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap Stop
        await tester.tap(find.byKey(const Key('stop_listening_button')));
        await tester.pumpAndSettle();

        expect(find.byType(ConfirmationCard), findsOneWidget);
        expect(find.byKey(const Key('confirmation_title_text')), findsOneWidget);

        // Tap Save
        await tester.tap(find.byKey(const Key('confirmation_save_button')));
        await tester.pumpAndSettle();

        // Verify action persisted in database
        final allInDb = await db.select(db.reminderTable).get();
        expect(allInDb.length, equals(1));
        final saved = allInDb.first;
        expect(saved.title.toLowerCase(), equals('sarah'));

        final actionsInDb = await db.select(db.actionTable).get();
        expect(actionsInDb.length, equals(1));
        expect(actionsInDb.first.actionType, equals('CALL'));

        await cleanupTester(tester);
      },
    );

    testWidgets(
      'Direct Text Input Flow: Type text in bottom bar -> Submit -> Confirmation -> Persist',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Find text input field inside TextInputField
        final textField = find.descendant(
          of: find.byType(TextInputField),
          matching: find.byType(TextField),
        );
        expect(textField, findsOneWidget);

        // Enter reminder text
        await tester.enterText(textField, 'Remind me to buy groceries tomorrow at 10am');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        // Submit via submit icon button
        await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
        await tester.pumpAndSettle();

        // Confirmation card appears
        expect(find.byType(ConfirmationCard), findsOneWidget);
        expect(find.text('buy groceries'), findsOneWidget);

        // Save
        await tester.tap(find.byKey(const Key('confirmation_save_button')));
        await tester.pumpAndSettle();

        // Verify in DB and timeline
        final allInDb = await db.select(db.reminderTable).get();
        expect(allInDb.length, equals(1));
        expect(allInDb.first.title, equals('buy groceries'));
        expect(find.byType(ReminderTile), findsOneWidget);

        await cleanupTester(tester);
      },
    );

    testWidgets(
      'Conflict Detection in Save Flow: Highlights conflict warning for overlapping reminder',
      (tester) async {
        // Pre-populate an existing reminder at tomorrow 10:00 AM UTC
        final existingTimeUtc = DateTime.utc(2026, 8, 18, 10, 0);
        final nowIso = DateTime.utc(2026, 8, 17, 9, 0).toIso8601String();

        await db.into(db.reminderTable).insert(
              ReminderTableCompanion.insert(
                id: 'existing-r1',
                title: 'Existing Team Sync',
                intentType: 'GENERAL',
                status: const Value('PENDING'),
                createdAt: nowIso,
                updatedAt: nowIso,
              ),
            );

        await db.into(db.triggerTable).insert(
              TriggerTableCompanion.insert(
                id: 'trigger-r1',
                reminderId: 'existing-r1',
                triggerType: 'SCHEDULED_TIME',
                scheduledTimeUtc: existingTimeUtc.toIso8601String(),
                notificationScheduled: const Value(1),
                deliveryStatus: const Value('scheduled'),
              ),
            );

        speechBridge.transcriptsToEmit = ['Remind me to buy groceries tomorrow at 10am'];

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // 1 existing reminder shown in timeline
        expect(find.text('Existing Team Sync'), findsOneWidget);

        // Voice create conflicting reminder
        await tester.tap(find.byType(MicButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.byKey(const Key('stop_listening_button')));
        await tester.pumpAndSettle();

        // Tap Save on confirmation card -> triggers conflict check
        expect(find.byType(ConfirmationCard), findsOneWidget);
        await tester.tap(find.byKey(const Key('confirmation_save_button')));
        await tester.pumpAndSettle();

        expect(find.byType(ConflictWarning), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(ConflictWarning),
            matching: find.textContaining('Existing Team Sync'),
          ),
          findsWidgets,
        );

        // Tap Save Anyway on ConflictWarning (OutlinedButton)
        await tester.tap(find.widgetWithText(OutlinedButton, 'Save Anyway'));
        await tester.pumpAndSettle();

        final allInDb = await db.select(db.reminderTable).get();
        expect(allInDb.length, equals(2));

        await cleanupTester(tester);
      },
    );
  });
}
