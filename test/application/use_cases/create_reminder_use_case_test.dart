import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/application/use_cases/create_reminder_use_case.dart';
import 'package:katala/data/database/database.dart';
import 'package:katala/data/repositories/reminder_repository.dart';
import 'package:katala/data/repositories/reminder_repository_impl.dart';
import 'package:katala/domain/conflict_detector.dart';
import 'package:katala/domain/entities/resolved_contact.dart';
import 'package:katala/domain/enums/intent_type.dart';
import 'package:katala/domain/enums/reminder_status.dart';
import 'package:katala/domain/enums/validation_issue.dart';
import 'package:katala/domain/errors.dart';
import 'package:katala/domain/nlp/nlp_pipeline.dart';
import '../../test_helpers/fake_clock.dart';
import '../../test_helpers/fake_contact_bridge.dart';
import '../../test_helpers/fake_notification_bridge.dart';

void main() {
  group('CreateReminderUseCase', () {
    late AppDatabase db;
    late ReminderRepository repository;
    late FakeNotificationBridge notificationBridge;
    late FakeContactBridge contactBridge;
    late FakeClock fakeClock;
    late CreateReminderUseCase useCase;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repository = ReminderRepositoryImpl(db);
      notificationBridge = FakeNotificationBridge();
      contactBridge = FakeContactBridge([
        const ResolvedContact(
          platformId: 'c-1',
          displayName: 'Adam Smith',
          phoneNumber: '+639171234567',
        ),
      ]);
      // Monday Aug 17, 2026 at 10:00 AM UTC
      fakeClock = FakeClock(DateTime.utc(2026, 8, 17, 10, 0), timezone: 'UTC');

      useCase = CreateReminderUseCase(
        nlpPipeline: const NlpPipeline(),
        contactBridge: contactBridge,
        conflictDetector: const ConflictDetector(),
        repository: repository,
        notificationBridge: notificationBridge,
        clock: fakeClock,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Full Create flow: transcript -> NLP -> contact resolution -> persist -> schedule notification', () async {
      final result = await useCase.executeFromTranscript('Call Adam tomorrow at 3pm');

      expect(result.isSuccess, isTrue);
      final reminder = result.valueOrNull!;

      expect(reminder.id, isNotEmpty);
      expect(reminder.title, 'adam');
      expect(reminder.intentType, IntentType.call);
      expect(reminder.status, ReminderStatus.pending);
      expect(reminder.trigger?.scheduledTimeUtc, DateTime.utc(2026, 8, 18, 15, 0));
      expect(reminder.action?.contactName, 'Adam Smith');
      expect(reminder.action?.contactPhone, '+639171234567');
      expect(reminder.trigger?.notificationScheduled, isTrue);

      // Verify notification bridge received schedule call
      expect(await notificationBridge.getScheduledIds(), isNotEmpty);
    });

    test('Validation issue (missing time) returns ValidationFailed', () async {
      final result = await useCase.executeFromTranscript('Remind me to buy groceries');

      expect(result.isFailure, isTrue);
      final error = result.errorOrNull!;
      expect(error, isA<ValidationFailed>());
      expect((error as ValidationFailed).issues, contains(ValidationIssue.missingTime));
    });

    test('Multiple contact matches returns ContactDisambiguationRequired', () async {
      contactBridge.contacts.add(const ResolvedContact(
        platformId: 'c-2',
        displayName: 'Adam Johnson',
        phoneNumber: '+639180000000',
      ));

      final result = await useCase.executeFromTranscript('Call Adam tomorrow at 3pm');

      expect(result.isFailure, isTrue);
      final error = result.errorOrNull!;
      expect(error, isA<ContactDisambiguationRequired>());
      expect((error as ContactDisambiguationRequired).candidates, hasLength(2));
    });

    test('Conflict detected within ±15 minutes returns ConflictDetected, saveAnyway bypasses', () async {
      // 1. Create first reminder at 3:00 PM
      final r1 = await useCase.executeFromTranscript('Remind me to do task 1 tomorrow at 3pm');
      expect(r1.isSuccess, isTrue);

      // 2. Attempt to create conflicting reminder at 3:10 PM
      final conflicting = await useCase.executeFromTranscript('Remind me to do task 2 tomorrow at 3:10pm');
      expect(conflicting.isFailure, isTrue);
      expect(conflicting.errorOrNull, isA<ConflictDetected>());

      // 3. Save anyway overrides the conflict check
      final saveAnywayResult =
          await useCase.executeFromTranscript('Remind me to do task 2 tomorrow at 3:10pm', saveAnyway: true);
      expect(saveAnywayResult.isSuccess, isTrue);
    });

    test('Notification scheduling failure still persists reminder (DB authoritative)', () async {
      notificationBridge.errorToThrow = Exception('OS notification limit reached');

      final result = await useCase.executeFromTranscript('Remind me to stretch tomorrow at 9am');

      expect(result.isSuccess, isTrue);
      final reminder = result.valueOrNull!;

      // Persisted in DB
      final inDb = await repository.getById(reminder.id);
      expect(inDb, isNotNull);
      expect(inDb!.title, 'stretch');
    });
  });
}
