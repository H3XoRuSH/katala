import 'package:flutter_test/flutter_test.dart';
import 'package:katala/domain/entities/reminder.dart';
import 'package:katala/domain/entities/resolved_contact.dart';
import 'package:katala/domain/entities/trigger.dart';
import 'package:katala/domain/enums/delivery_status.dart';
import 'package:katala/domain/enums/intent_type.dart';
import 'package:katala/domain/enums/reminder_status.dart';
import 'package:katala/domain/enums/speech_availability.dart';
import 'package:katala/domain/enums/trigger_type.dart';
import '../test_helpers/fake_action_bridge.dart';
import '../test_helpers/fake_contact_bridge.dart';
import '../test_helpers/fake_notification_bridge.dart';
import '../test_helpers/fake_speech_bridge.dart';

void main() {
  group('Platform Bridges & Test Doubles', () {
    test('FakeSpeechBridge emits transcripts and reports availability', () async {
      final bridge = FakeSpeechBridge(
        mockAvailability: SpeechAvailability.available,
        mockOnDeviceAvailable: true,
        transcriptsToEmit: ['remind me', 'remind me to call Adam'],
      );

      expect(await bridge.availability, SpeechAvailability.available);
      expect(await bridge.isOnDeviceAvailable, isTrue);

      final stream = bridge.startListening();
      expect(
        stream,
        emitsInOrder(['remind me', 'remind me to call Adam']),
      );

      final finalResult = await bridge.stopListening();
      expect(finalResult, 'remind me to call Adam');
    });

    test('FakeNotificationBridge schedules, cancels, and reconciles state', () async {
      final bridge = FakeNotificationBridge(maxNotifications: 60);
      await bridge.configureCategories();
      expect(bridge.categoriesConfigured, isTrue);

      final r1 = Reminder(
        id: 'rem-1',
        title: 'Buy Milk',
        intentType: IntentType.general,
        status: ReminderStatus.pending,
        createdAt: DateTime.utc(2026, 8, 17, 10, 0),
        updatedAt: DateTime.utc(2026, 8, 17, 10, 0),
        trigger: Trigger(
          id: 'trig-1',
          reminderId: 'rem-1',
          triggerType: TriggerType.scheduledTime,
          scheduledTimeUtc: DateTime.utc(2026, 8, 17, 14, 0),
          deliveryStatus: DeliveryStatus.scheduled,
        ),
      );

      final r2 = Reminder(
        id: 'rem-2',
        title: 'Call Doctor',
        intentType: IntentType.call,
        status: ReminderStatus.pending,
        createdAt: DateTime.utc(2026, 8, 17, 10, 0),
        updatedAt: DateTime.utc(2026, 8, 17, 10, 0),
        trigger: Trigger(
          id: 'trig-2',
          reminderId: 'rem-2',
          triggerType: TriggerType.scheduledTime,
          scheduledTimeUtc: DateTime.utc(2026, 8, 17, 15, 0),
          deliveryStatus: DeliveryStatus.scheduled,
        ),
      );

      // Schedule r1
      final notifId1 = await bridge.schedule(r1);
      expect(await bridge.getScheduledIds(), contains(notifId1));

      // Reconcile: r1 should remain, r2 should be scheduled
      final reconciliation = await bridge.reconcile(
        toSchedule: [r1, r2],
        knownIds: [notifId1],
      );

      expect(reconciliation.scheduledIds, contains('rem-2'));
      expect(reconciliation.cancelledIds, isEmpty);

      // Cancel for reminder 1
      await bridge.cancelForReminder('rem-1');
      expect(await bridge.getScheduledIds(), isNot(contains(notifId1)));
    });

    test('FakeContactBridge resolves exact, prefix, and substring names', () async {
      const c1 = ResolvedContact(
        platformId: 'c-1',
        displayName: 'Adam Smith',
        phoneNumber: '+639171234567',
      );
      const c2 = ResolvedContact(
        platformId: 'c-2',
        displayName: 'Sarah Connor',
        phoneNumber: '+639187654321',
      );

      final bridge = FakeContactBridge([c1, c2]);

      // Exact match
      final exact = await bridge.resolve('Adam Smith');
      expect(exact, contains(c1));

      // Prefix match on first/last name
      final prefix = await bridge.resolve('sar');
      expect(prefix, contains(c2));

      // Get by platform ID
      final byId = await bridge.getById('c-1');
      expect(byId, equals(c1));

      // Non-existent
      final empty = await bridge.resolve('Unknown Person');
      expect(empty, isEmpty);
    });

    test('FakeActionBridge records dialer, SMS, and URL launches', () async {
      final bridge = FakeActionBridge();

      expect(await bridge.launchDialer('09171234567'), isTrue);
      expect(bridge.launchedDialerNumbers, contains('09171234567'));

      expect(await bridge.launchSms('09171234567', message: 'Hello'), isTrue);
      expect(bridge.launchedSms.first.phone, '09171234567');
      expect(bridge.launchedSms.first.message, 'Hello');

      expect(await bridge.launchUrl('https://katala.app'), isTrue);
      expect(bridge.launchedUrls, contains('https://katala.app'));
    });
  });
}
