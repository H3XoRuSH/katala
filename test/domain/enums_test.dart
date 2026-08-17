import 'package:flutter_test/flutter_test.dart';
import 'package:katala/domain/enums/action_type.dart';
import 'package:katala/domain/enums/delivery_status.dart';
import 'package:katala/domain/enums/intent_type.dart';
import 'package:katala/domain/enums/notification_category.dart';
import 'package:katala/domain/enums/reminder_status.dart';
import 'package:katala/domain/enums/speech_availability.dart';
import 'package:katala/domain/enums/trigger_type.dart';
import 'package:katala/domain/enums/validation_issue.dart';

void main() {
  group('Domain Enums Serialization & Deserialization', () {
    test('ReminderStatus matches DB CHECK constraint values', () {
      expect(ReminderStatus.pending.value, 'PENDING');
      expect(ReminderStatus.completed.value, 'COMPLETED');
      expect(ReminderStatus.snoozed.value, 'SNOOZED');
      expect(ReminderStatus.dismissed.value, 'DISMISSED');

      expect(ReminderStatus.fromValue('PENDING'), ReminderStatus.pending);
      expect(ReminderStatus.fromValue('COMPLETED'), ReminderStatus.completed);
      expect(ReminderStatus.fromValue('SNOOZED'), ReminderStatus.snoozed);
      expect(ReminderStatus.fromValue('DISMISSED'), ReminderStatus.dismissed);
    });

    test('IntentType matches DB CHECK constraint values', () {
      expect(IntentType.general.value, 'GENERAL');
      expect(IntentType.call.value, 'CALL');
      expect(IntentType.text.value, 'TEXT');
      expect(IntentType.email.value, 'EMAIL');
      expect(IntentType.openUrl.value, 'OPEN_URL');

      expect(IntentType.fromValue('GENERAL'), IntentType.general);
      expect(IntentType.fromValue('CALL'), IntentType.call);
      expect(IntentType.fromValue('TEXT'), IntentType.text);
      expect(IntentType.fromValue('EMAIL'), IntentType.email);
      expect(IntentType.fromValue('OPEN_URL'), IntentType.openUrl);
    });

    test('TriggerType matches DB CHECK constraint values', () {
      expect(TriggerType.scheduledTime.value, 'SCHEDULED_TIME');
      expect(TriggerType.geofence.value, 'GEOFENCE');

      expect(TriggerType.fromValue('SCHEDULED_TIME'), TriggerType.scheduledTime);
      expect(TriggerType.fromValue('GEOFENCE'), TriggerType.geofence);
    });

    test('ActionType matches DB CHECK constraint values', () {
      expect(ActionType.call.value, 'CALL');
      expect(ActionType.text.value, 'TEXT');
      expect(ActionType.email.value, 'EMAIL');
      expect(ActionType.openUrl.value, 'OPEN_URL');
      expect(ActionType.general.value, 'GENERAL');

      expect(ActionType.fromValue('CALL'), ActionType.call);
      expect(ActionType.fromValue('TEXT'), ActionType.text);
      expect(ActionType.fromValue('EMAIL'), ActionType.email);
      expect(ActionType.fromValue('OPEN_URL'), ActionType.openUrl);
      expect(ActionType.fromValue('GENERAL'), ActionType.general);
    });

    test('DeliveryStatus matches DB CHECK constraint values', () {
      expect(DeliveryStatus.scheduled.value, 'scheduled');
      expect(DeliveryStatus.deliveryUncertain.value, 'delivery_uncertain');
      expect(DeliveryStatus.deliveryMissed.value, 'delivery_missed');

      expect(DeliveryStatus.fromValue('scheduled'), DeliveryStatus.scheduled);
      expect(DeliveryStatus.fromValue('delivery_uncertain'), DeliveryStatus.deliveryUncertain);
      expect(DeliveryStatus.fromValue('delivery_missed'), DeliveryStatus.deliveryMissed);
    });

    test('ValidationIssue matches expected values', () {
      expect(ValidationIssue.missingTitle.value, 'missingTitle');
      expect(ValidationIssue.missingTime.value, 'missingTime');
      expect(ValidationIssue.ambiguousTime.value, 'ambiguousTime');
      expect(ValidationIssue.ambiguousContact.value, 'ambiguousContact');
      expect(ValidationIssue.unresolvedContact.value, 'unresolvedContact');
      expect(ValidationIssue.invalidUrl.value, 'invalidUrl');
      expect(ValidationIssue.timeInPast.value, 'timeInPast');
      expect(ValidationIssue.unrecognizedIntent.value, 'unrecognizedIntent');
      expect(ValidationIssue.incompleteAction.value, 'incompleteAction');
      expect(ValidationIssue.contactNotFound.value, 'contactNotFound');
    });

    test('SpeechAvailability matches expected values', () {
      expect(SpeechAvailability.available.value, 'available');
      expect(SpeechAvailability.unavailable.value, 'unavailable');
      expect(SpeechAvailability.permissionDenied.value, 'permissionDenied');
      expect(SpeechAvailability.notSupported.value, 'notSupported');
    });

    test('NotificationCategory matches expected identifiers', () {
      expect(NotificationCategory.general.value, 'REMINDER_GENERAL');
      expect(NotificationCategory.call.value, 'REMINDER_CALL');
      expect(NotificationCategory.text.value, 'REMINDER_TEXT');
      expect(NotificationCategory.url.value, 'REMINDER_URL');
    });
  });
}
