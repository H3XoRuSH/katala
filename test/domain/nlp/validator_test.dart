import 'package:flutter_test/flutter_test.dart';
import 'package:katala/domain/entities/parsed_reminder.dart';
import 'package:katala/domain/enums/intent_type.dart';
import 'package:katala/domain/enums/validation_issue.dart';
import 'package:katala/domain/nlp/validator.dart';
import '../../test_helpers/fake_clock.dart';

void main() {
  group('Stage 5: Validator', () {
    const validator = Validator();
    late FakeClock fakeClock;

    setUp(() {
      fakeClock = FakeClock(DateTime.utc(2026, 8, 17, 10, 0));
    });

    test('valid reminder produces zero validation issues', () {
      final parsed = ParsedReminder(
        title: 'Buy groceries',
        scheduledTime: DateTime.utc(2026, 8, 17, 14, 0),
        originalTranscript: 'remind me to buy groceries today at 2pm',
      );
      final issues = validator.validate(parsed, clock: fakeClock);
      expect(issues, isEmpty);
    });

    test('detects missingTitle', () {
      final parsed = ParsedReminder(
        title: null,
        scheduledTime: DateTime.utc(2026, 8, 17, 14, 0),
        originalTranscript: 'remind me today at 2pm',
      );
      final issues = validator.validate(parsed, clock: fakeClock);
      expect(issues, contains(ValidationIssue.missingTitle));
    });

    test('detects missingTime', () {
      const parsed = ParsedReminder(
        title: 'Buy milk',
        scheduledTime: null,
        originalTranscript: 'remind me to buy milk',
      );
      final issues = validator.validate(parsed, clock: fakeClock);
      expect(issues, contains(ValidationIssue.missingTime));
    });

    test('detects ambiguousTime', () {
      const parsed = ParsedReminder(
        title: 'Call John',
        scheduledTime: null,
        issues: [ValidationIssue.ambiguousTime],
        originalTranscript: 'remind me to call John at 3',
      );
      final issues = validator.validate(parsed, clock: fakeClock);
      expect(issues, contains(ValidationIssue.ambiguousTime));
      expect(issues, isNot(contains(ValidationIssue.missingTime)));
    });

    test('detects timeInPast', () {
      final parsed = ParsedReminder(
        title: 'Past meeting',
        scheduledTime: DateTime.utc(2026, 8, 17, 8, 0), // 8:00 AM is before 10:00 AM fakeClock
        originalTranscript: 'remind me at 8am',
      );
      final issues = validator.validate(parsed, clock: fakeClock);
      expect(issues, contains(ValidationIssue.timeInPast));
    });

    test('detects incompleteAction for call/text without contact or phone', () {
      final parsed = ParsedReminder(
        title: 'call',
        intentType: IntentType.call,
        scheduledTime: DateTime.utc(2026, 8, 17, 14, 0),
        originalTranscript: 'call tomorrow at 2pm',
      );
      final issues = validator.validate(parsed, clock: fakeClock);
      expect(issues, contains(ValidationIssue.incompleteAction));
    });
  });
}
