import 'package:flutter_test/flutter_test.dart';
import 'package:katala/domain/enums/reminder_status.dart';
import 'package:katala/domain/enums/speech_availability.dart';
import 'package:katala/domain/enums/validation_issue.dart';
import 'package:katala/domain/errors.dart';
import 'package:katala/domain/result.dart';

void main() {
  group('Result<T, E> & AppError Hierarchy', () {
    test('Result success pattern matching and accessors', () {
      const Result<int, AppError> result = Success(42);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.valueOrNull, 42);
      expect(result.errorOrNull, isNull);

      final mapped = result.map((v) => 'Value: $v');
      expect(mapped.valueOrNull, 'Value: 42');

      final patternMatched = switch (result) {
        Success(:final value) => 'Got $value',
        Failure(:final error) => 'Failed: ${error.userMessage}',
      };
      expect(patternMatched, 'Got 42');
    });

    test('Result failure pattern matching and accessors', () {
      const Result<int, AppError> result = Failure(ValidationFailed([ValidationIssue.missingTitle]));

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.errorOrNull, isA<ValidationFailed>());

      final mapped = result.map((v) => 'Value: $v');
      expect(mapped.isFailure, isTrue);
      expect(mapped.errorOrNull, isA<ValidationFailed>());

      final patternMatched = switch (result) {
        Success(:final value) => 'Got $value',
        Failure(:final error) => 'Failed: ${error.userMessage}',
      };
      expect(patternMatched, contains('Please provide the missing details'));
    });

    test('All domain errors provide non-empty userMessage and technicalDetails', () {
      final errors = <AppError>[
        const ValidationFailed([ValidationIssue.missingTitle]),
        const ConflictDetected([]),
        const InvalidStateTransition(ReminderStatus.pending, ReminderStatus.pending),
        TimeInPast(DateTime.utc(2026, 1, 1)),
        const ContactDisambiguationRequired('John', []),
        const SchedulingFailed('Platform channel unavailable'),
        const PersistenceFailed('SQLite disk I/O error'),
        const NotificationActionFailed('Action ID unknown'),
        const SpeechNotAvailable(SpeechAvailability.unavailable),
        const PermissionDenied('android.permission.RECORD_AUDIO'),
        const NotificationLimitReached(64),
        const CannotLaunchUrl('tel:12345'),
        const UnrecognizedIntent('gibberish text'),
        const NoEntitiesExtracted(''),
        const AmbiguousTimeResolution('tomorrow around lunch'),
      ];

      for (final error in errors) {
        expect(error.userMessage, isNotEmpty);
        expect(error.technicalDetails, isNotNull);
        expect(error.technicalDetails, isNotEmpty);
      }
    });
  });
}
