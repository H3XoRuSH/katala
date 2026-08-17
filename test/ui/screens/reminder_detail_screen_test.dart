import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/application/providers.dart';
import 'package:katala/data/database/database.dart';
import 'package:katala/data/repositories/reminder_repository_impl.dart';
import 'package:katala/domain/entities/action.dart' as entity;
import 'package:katala/domain/entities/reminder.dart';
import 'package:katala/domain/entities/trigger.dart';
import 'package:katala/domain/enums/action_type.dart';
import 'package:katala/domain/enums/delivery_status.dart';
import 'package:katala/domain/enums/intent_type.dart';
import 'package:katala/domain/enums/reminder_status.dart';
import 'package:katala/domain/enums/trigger_type.dart';
import 'package:katala/ui/screens/reminder_detail_screen.dart';
import '../../test_helpers/fake_action_bridge.dart';
import '../../test_helpers/fake_clock.dart';
import '../../test_helpers/fake_notification_bridge.dart';
import '../../test_helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ReminderRepositoryImpl repo;
  late FakeNotificationBridge fakeNotif;
  late FakeActionBridge fakeAction;
  late FakeClock fakeClock;

  setUp(() {
    db = AppDatabase(createInMemoryDatabaseConnection());
    repo = ReminderRepositoryImpl(db);
    fakeNotif = FakeNotificationBridge();
    fakeAction = FakeActionBridge();
    fakeClock = FakeClock(DateTime.utc(2026, 8, 17, 10, 0));
  });

  tearDown(() async {
    await db.close();
  });

  Reminder createTestReminder({
    required String id,
    required String title,
    ReminderStatus status = ReminderStatus.pending,
    IntentType intentType = IntentType.call,
  }) {
    final now = DateTime.utc(2026, 8, 17, 10, 0);
    return Reminder(
      id: id,
      title: title,
      notes: 'Test notes',
      status: status,
      intentType: intentType,
      originalTranscript: 'Call Bob at 11am',
      createdAt: now,
      updatedAt: now,
      trigger: Trigger(
        id: 'trig-$id',
        reminderId: id,
        triggerType: TriggerType.scheduledTime,
        scheduledTimeUtc: DateTime.utc(2026, 8, 17, 11, 0),
        deliveryStatus: DeliveryStatus.scheduled,
      ),
      action: entity.Action(
        id: 'act-$id',
        reminderId: id,
        actionType: ActionType.call,
        contactName: 'Bob',
        contactPhone: '+15550001',
      ),
    );
  }

  testWidgets('ReminderDetailScreen renders all fields and completes reminder on tap', (tester) async {
    final reminder = createTestReminder(id: 'rem-101', title: 'Call Bob');
    await repo.insertRaw(reminder, reminder.trigger!, reminder.action);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          reminderRepositoryProvider.overrideWithValue(repo),
          notificationBridgeProvider.overrideWithValue(fakeNotif),
          actionBridgeProvider.overrideWithValue(fakeAction),
          clockProvider.overrideWithValue(fakeClock),
        ],
        child: MaterialApp(
          home: ReminderDetailScreen(reminder: reminder),
        ),
      ),
    );

    // Verify fields rendered
    expect(find.text('Reminder Details'), findsOneWidget);
    expect(find.byKey(const Key('detail_title_text')), findsOneWidget);
    expect(find.text('Call Bob'), findsOneWidget);
    expect(find.text('Test notes'), findsOneWidget);
    expect(find.text('"Call Bob at 11am"'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('+15550001'), findsOneWidget);
    // Tap Complete
    await tester.ensureVisible(find.byKey(const Key('detail_complete_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail_complete_button')));
    await tester.pumpAndSettle();

    // Verify status changed to COMPLETED
    expect(find.text('COMPLETED'), findsWidgets);
  });

  testWidgets('ReminderDetailScreen allows inline editing and saving changes', (tester) async {
    final reminder = createTestReminder(id: 'rem-102', title: 'Old Title');
    await repo.insertRaw(reminder, reminder.trigger!, reminder.action);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          reminderRepositoryProvider.overrideWithValue(repo),
          notificationBridgeProvider.overrideWithValue(fakeNotif),
          actionBridgeProvider.overrideWithValue(fakeAction),
          clockProvider.overrideWithValue(fakeClock),
        ],
        child: MaterialApp(
          home: ReminderDetailScreen(reminder: reminder),
        ),
      ),
    );

    // Toggle edit mode
    await tester.tap(find.byKey(const Key('detail_edit_toggle_button')));
    await tester.pump();

    expect(find.byKey(const Key('detail_edit_title_input')), findsOneWidget);

    // Enter new title
    await tester.enterText(find.byKey(const Key('detail_edit_title_input')), 'New Title');
    await tester.tap(find.byKey(const Key('detail_save_edits_button')));
    await tester.pump();

    // Verify updated title
    expect(find.text('New Title'), findsOneWidget);
  });

  testWidgets('ReminderDetailScreen hides edit and complete buttons for completed reminders', (tester) async {
    final reminder = createTestReminder(
      id: 'rem-103',
      title: 'Done Task',
      status: ReminderStatus.completed,
    );
    await repo.insertRaw(reminder, reminder.trigger!, reminder.action);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          reminderRepositoryProvider.overrideWithValue(repo),
          notificationBridgeProvider.overrideWithValue(fakeNotif),
          actionBridgeProvider.overrideWithValue(fakeAction),
          clockProvider.overrideWithValue(fakeClock),
        ],
        child: MaterialApp(
          home: ReminderDetailScreen(reminder: reminder),
        ),
      ),
    );

    expect(find.text('COMPLETED'), findsOneWidget);
    expect(find.byKey(const Key('detail_complete_button')), findsNothing);
    expect(find.byKey(const Key('detail_edit_toggle_button')), findsNothing);
  });
}
