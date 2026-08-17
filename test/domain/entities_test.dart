import 'package:flutter_test/flutter_test.dart';
import 'package:katala/domain/entities/action.dart';
import 'package:katala/domain/entities/parsed_reminder.dart';
import 'package:katala/domain/entities/reminder.dart';
import 'package:katala/domain/entities/resolved_contact.dart';
import 'package:katala/domain/entities/trigger.dart';
import 'package:katala/domain/entities/validated_reminder.dart';
import 'package:katala/domain/enums/action_type.dart';
import 'package:katala/domain/enums/intent_type.dart';
import 'package:katala/domain/enums/reminder_status.dart';
import 'package:katala/domain/enums/validation_issue.dart';

void main() {
  group('Domain Entities & Value Objects', () {
    test('Reminder entity instantiates and copyWith works correctly', () {
      final now = DateTime.utc(2026, 8, 16, 12, 0);
      final trigger = Trigger(
        id: 'trig-1',
        reminderId: 'rem-1',
        scheduledTimeUtc: now,
      );
      const action = Action(
        id: 'act-1',
        reminderId: 'rem-1',
        actionType: ActionType.call,
        contactName: 'Adam',
      );

      final reminder = Reminder(
        id: 'rem-1',
        title: 'Call Adam',
        intentType: IntentType.call,
        status: ReminderStatus.pending,
        createdAt: now,
        updatedAt: now,
        trigger: trigger,
        action: action,
      );

      expect(reminder.id, 'rem-1');
      expect(reminder.title, 'Call Adam');
      expect(reminder.version, 1);
      expect(reminder.snoozeCount, 0);
      expect(reminder.trigger?.id, 'trig-1');
      expect(reminder.action?.contactName, 'Adam');

      final updated = reminder.copyWith(title: 'Call Adam ASAP', version: 2);
      expect(updated.title, 'Call Adam ASAP');
      expect(updated.version, 2);
      expect(updated.id, 'rem-1');
    });

    test('ResolvedContact equality and string representation', () {
      const contact1 = ResolvedContact(
        platformId: 'p-1',
        displayName: 'John Doe',
        phoneNumber: '+639171234567',
        allPhoneNumbers: ['+639171234567'],
      );
      const contact2 = ResolvedContact(
        platformId: 'p-1',
        displayName: 'John Doe',
        phoneNumber: '+639171234567',
      );

      expect(contact1, contact2);
      expect(contact1.toString(), contains('John Doe'));
    });

    test('ParsedReminder handles nullable fields and validation issues', () {
      const parsed = ParsedReminder(
        title: 'Meeting tomorrow',
        intentType: IntentType.general,
        issues: [ValidationIssue.ambiguousTime],
        originalTranscript: 'meeting tomorrow at 2',
      );

      expect(parsed.title, 'Meeting tomorrow');
      expect(parsed.scheduledTime, isNull);
      expect(parsed.issues, contains(ValidationIssue.ambiguousTime));
    });

    test('ValidatedReminder requires validated fields', () {
      final scheduledTime = DateTime.utc(2026, 8, 17, 14, 0);
      final validated = ValidatedReminder(
        title: 'Meeting tomorrow',
        scheduledTime: scheduledTime,
        timezone: 'Asia/Manila',
        intentType: IntentType.general,
        originalTranscript: 'meeting tomorrow at 2pm',
      );

      expect(validated.title, 'Meeting tomorrow');
      expect(validated.scheduledTime, scheduledTime);
      expect(validated.timezone, 'Asia/Manila');
    });
  });
}
