import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/application/providers.dart';
import 'package:katala/data/database/database.dart';
import 'package:katala/data/repositories/reminder_repository_impl.dart';
import 'package:katala/domain/entities/reminder.dart';
import 'package:katala/domain/entities/trigger.dart';
import 'package:katala/domain/enums/delivery_status.dart';
import 'package:katala/domain/enums/intent_type.dart';
import 'package:katala/domain/enums/reminder_status.dart';
import 'package:katala/domain/enums/trigger_type.dart';
import 'package:katala/platform/permissions.dart';
import 'package:katala/ui/screens/home_screen.dart';
import 'package:katala/ui/widgets/empty_state.dart';
import 'package:katala/ui/widgets/mic_button.dart';
import 'package:katala/ui/widgets/reliability_banner.dart';
import 'package:katala/ui/widgets/timeline_group.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../test_helpers/fake_action_bridge.dart';
import '../../test_helpers/fake_clock.dart';
import '../../test_helpers/fake_contact_bridge.dart';
import '../../test_helpers/fake_notification_bridge.dart';
import '../../test_helpers/fake_permission_bridge.dart';
import '../../test_helpers/fake_speech_bridge.dart';
import '../../test_helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ReminderRepositoryImpl repo;
  late FakeNotificationBridge fakeNotif;
  late FakeActionBridge fakeAction;
  late FakeContactBridge fakeContact;
  late FakeSpeechBridge fakeSpeech;
  late FakePermissionBridge fakePermission;
  late FakeClock fakeClock;

  final now = DateTime.utc(2026, 8, 17, 10, 0);

  setUp(() {
    SharedPreferences.setMockInitialValues({'has_completed_onboarding': true});
    db = AppDatabase(createInMemoryDatabaseConnection());
    repo = ReminderRepositoryImpl(db);
    fakeNotif = FakeNotificationBridge();
    fakeAction = FakeActionBridge();
    fakeContact = FakeContactBridge();
    fakeSpeech = FakeSpeechBridge();
    fakePermission = FakePermissionBridge();
    fakeClock = FakeClock(now);
  });

  tearDown(() async {
    await db.close();
  });

  Widget createSubject({List<Reminder>? fixedReminders}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        reminderRepositoryProvider.overrideWithValue(repo),
        notificationBridgeProvider.overrideWithValue(fakeNotif),
        actionBridgeProvider.overrideWithValue(fakeAction),
        contactBridgeProvider.overrideWithValue(fakeContact),
        speechBridgeProvider.overrideWithValue(fakeSpeech),
        permissionBridgeProvider.overrideWithValue(fakePermission),
        clockProvider.overrideWithValue(fakeClock),
        if (fixedReminders != null) pendingRemindersStreamProvider.overrideWith((ref) => Stream.value(fixedReminders)),
      ],
      child: const MaterialApp(
        home: HomeScreen(),
      ),
    );
  }

  Future<Reminder> insertReminder({
    required String id,
    required String title,
    required DateTime scheduledTimeUtc,
    DeliveryStatus deliveryStatus = DeliveryStatus.scheduled,
  }) async {
    final reminder = Reminder(
      id: id,
      title: title,
      status: ReminderStatus.pending,
      intentType: IntentType.general,
      snoozeCount: 0,
      version: 1,
      createdAt: now,
      updatedAt: now,
    );
    final trigger = Trigger(
      id: 'trig-$id',
      reminderId: id,
      triggerType: TriggerType.scheduledTime,
      scheduledTimeUtc: scheduledTimeUtc,
      deliveryStatus: deliveryStatus,
    );
    return repo.insertRaw(reminder, trigger, null);
  }

  testWidgets('Renders empty state when database has no reminders', (tester) async {
    await tester.pumpWidget(createSubject(fixedReminders: []));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyTimelineState), findsOneWidget);
    expect(find.text('No reminders yet'), findsOneWidget);
    expect(find.byType(MicButton), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Renders timeline groups with reminder tiles when reminders exist', (tester) async {
    final r1 = await insertReminder(
      id: 'rem-today',
      title: 'Submit quarterly report',
      scheduledTimeUtc: DateTime.utc(2026, 8, 17, 14, 0),
    );
    final r2 = await insertReminder(
      id: 'rem-tomorrow',
      title: 'Dentist checkup',
      scheduledTimeUtc: DateTime.utc(2026, 8, 18, 9, 0),
    );

    await tester.pumpWidget(createSubject(fixedReminders: [r1, r2]));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyTimelineState), findsNothing);
    expect(find.byType(TimelineGroup), findsWidgets);
    expect(find.text('Submit quarterly report'), findsOneWidget);
    expect(find.text('Dentist checkup'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Swipe right on ReminderTile marks reminder complete', (tester) async {
    final r = await insertReminder(
      id: 'rem-swipe',
      title: 'Buy groceries',
      scheduledTimeUtc: DateTime.utc(2026, 8, 17, 12, 0),
    );

    await tester.pumpWidget(createSubject(fixedReminders: [r]));
    await tester.pumpAndSettle();

    expect(find.text('Buy groceries'), findsOneWidget);

    // Swipe right on Dismissible tile
    await tester.drag(find.text('Buy groceries'), const Offset(500, 0));
    await tester.pumpAndSettle();

    // Verify DB updated to completed
    final updated = await repo.getById('rem-swipe');
    expect(updated?.status, ReminderStatus.completed);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Renders ReliabilityBanner when uncertain deliveries exist', (tester) async {
    final r = await insertReminder(
      id: 'rem-uncertain',
      title: 'Uncertain alarm',
      scheduledTimeUtc: DateTime.utc(2026, 8, 17, 8, 0),
      deliveryStatus: DeliveryStatus.deliveryUncertain,
    );

    await tester.pumpWidget(createSubject(fixedReminders: [r]));
    await tester.pumpAndSettle();

    expect(find.byType(ReliabilityBanner), findsOneWidget);
    expect(find.text('Uncertain alarm'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Pull-to-refresh triggers reconciliation pass cleanly', (tester) async {
    final r = await insertReminder(
      id: 'rem-pull',
      title: 'Check mail',
      scheduledTimeUtc: DateTime.utc(2026, 8, 17, 15, 0),
    );

    await tester.pumpWidget(createSubject(fixedReminders: [r]));
    await tester.pumpAndSettle();

    // Pull down scroll view
    await tester.fling(find.byType(ListView).first, const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Check mail'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Reminders scheduled in the same minute are categorized as Today, not Overdue', (tester) async {
    // Current time: 10:00:35 UTC
    fakeClock.set(DateTime.utc(2026, 8, 17, 10, 0, 35));

    // Reminder scheduled for 10:00:00 UTC (same minute)
    final r = await insertReminder(
      id: 'rem-same-minute',
      title: 'Current minute reminder',
      scheduledTimeUtc: DateTime.utc(2026, 8, 17, 10, 0, 0),
    );

    await tester.pumpWidget(createSubject(fixedReminders: [r]));
    await tester.pumpAndSettle();

    // Should appear in Today group, not Overdue
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('OVERDUE'), findsNothing);
    expect(find.text('Current minute reminder'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Reminders scheduled 1 minute ahead in local timezone are categorized as Today, not Overdue',
      (tester) async {
    // Current time: 22:55:00 Local (UTC+8) -> 14:55:00 UTC
    // Using a local (non-UTC) DateTime to simulate SystemClock on physical devices
    fakeClock.set(DateTime(2026, 8, 17, 22, 55, 0));

    // Reminder scheduled for 1 minute in the future: 22:56:00 Local -> 14:56:00 UTC
    final r = await insertReminder(
      id: 'rem-in-one-minute',
      title: 'Call Gab',
      scheduledTimeUtc: DateTime(2026, 8, 17, 22, 56, 0).toUtc(),
    );

    await tester.pumpWidget(createSubject(fixedReminders: [r]));
    await tester.pumpAndSettle();

    // Must be in TODAY, never OVERDUE
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('OVERDUE'), findsNothing);
    expect(find.text('Call Gab'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
