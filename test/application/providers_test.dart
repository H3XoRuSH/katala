import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/application/providers.dart';
import 'package:katala/data/database/database.dart';
import '../test_helpers/fake_action_bridge.dart';
import '../test_helpers/fake_clock.dart';
import '../test_helpers/fake_contact_bridge.dart';
import '../test_helpers/fake_notification_bridge.dart';
import '../test_helpers/fake_speech_bridge.dart';

void main() {
  group('Riverpod Providers Wiring', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 8, 17, 10, 0))),
          speechBridgeProvider.overrideWithValue(FakeSpeechBridge()),
          notificationBridgeProvider.overrideWithValue(FakeNotificationBridge()),
          contactBridgeProvider.overrideWithValue(FakeContactBridge()),
          actionBridgeProvider.overrideWithValue(FakeActionBridge()),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('All application use case providers resolve with overrides', () {
      expect(container.read(createReminderUseCaseProvider), isNotNull);
      expect(container.read(completeReminderUseCaseProvider), isNotNull);
      expect(container.read(snoozeReminderUseCaseProvider), isNotNull);
      expect(container.read(deleteReminderUseCaseProvider), isNotNull);
      expect(container.read(undoDeleteReminderUseCaseProvider), isNotNull);
      expect(container.read(editReminderUseCaseProvider), isNotNull);
      expect(container.read(handleNotificationActionUseCaseProvider), isNotNull);
      expect(container.read(reconcileNotificationsUseCaseProvider), isNotNull);
      expect(container.read(resolveContactsUseCaseProvider), isNotNull);
    });

    test('Stream providers react to database changes', () async {
      final createUseCase = container.read(createReminderUseCaseProvider);

      // Create reminder via use case
      final createResult = await createUseCase.executeFromTranscript('Remind me to hydrate tomorrow at 8am');
      expect(createResult.isSuccess, isTrue);

      final pendingReminders = await container.read(pendingRemindersStreamProvider.future);
      expect(pendingReminders, hasLength(1));
      expect(pendingReminders.first.title, 'hydrate');
    });
  });
}
