import 'package:flutter_test/flutter_test.dart';
import 'package:katala/application/use_cases/resolve_contacts_use_case.dart';
import 'package:katala/data/database/database.dart';
import 'package:katala/data/repositories/reminder_repository_impl.dart';
import 'package:katala/domain/entities/action.dart';
import 'package:katala/domain/entities/reminder.dart';
import 'package:katala/domain/entities/resolved_contact.dart';
import 'package:katala/domain/entities/trigger.dart';
import 'package:katala/domain/enums/action_type.dart';
import 'package:katala/domain/enums/delivery_status.dart';
import 'package:katala/domain/enums/intent_type.dart';
import 'package:katala/domain/enums/reminder_status.dart';
import 'package:katala/domain/enums/trigger_type.dart';
import 'package:katala/domain/nlp/nlp_pipeline.dart';
import '../test_helpers/fake_clock.dart';
import '../test_helpers/fake_contact_bridge.dart';
import '../test_helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ReminderRepositoryImpl repo;
  late FakeClock clock;
  late NlpPipeline nlpPipeline;

  setUp(() {
    db = AppDatabase(createInMemoryDatabaseConnection());
    repo = ReminderRepositoryImpl(db);
    clock = FakeClock(DateTime.utc(2026, 8, 17, 10, 0));
    nlpPipeline = const NlpPipeline();
  });

  tearDown(() async {
    await db.close();
  });

  group('TASK-124 — Performance Profiling Benchmarks', () {
    test('NLP Pipeline Benchmark: parsing latency is < 100ms per utterance', () {
      final sampleUtterances = [
        'Remind me to call John Doe tomorrow at 3pm',
        'Text Mom I will be late at 6:30 tonight',
        'Buy milk in 45 minutes',
        'Pay rent on the 1st of next month at 9am',
        'Open https://github.com next Friday at 2pm',
        'Check oven in 10 minutes',
        'Meeting with Alice Smith next Monday morning',
        'Dentist appointment with Dr. Johnson on August 25 at 14:00',
        'Send email to team about quarterly update tomorrow at 11am',
        'Take medication every day at 8am',
      ];

      // Warm-up run
      for (final utterance in sampleUtterances) {
        nlpPipeline.parse(utterance, clock: clock);
      }

      final stopwatch = Stopwatch()..start();
      const iterations = 5;

      for (var i = 0; i < iterations; i++) {
        for (final utterance in sampleUtterances) {
          final itemWatch = Stopwatch()..start();
          final result = nlpPipeline.parse(utterance, clock: clock);
          itemWatch.stop();

          expect(result, isNotNull);
          // Each individual NLP parse should stay well below 100ms budget
          expect(
            itemWatch.elapsedMilliseconds,
            lessThan(100),
            reason: 'NLP parse for "$utterance" took ${itemWatch.elapsedMilliseconds}ms (budget < 100ms)',
          );
        }
      }

      stopwatch.stop();
      final totalRuns = iterations * sampleUtterances.length;
      final avgMs = stopwatch.elapsedMilliseconds / totalRuns;

      // Average parse time across all utterances
      expect(avgMs, lessThan(25), reason: 'Average NLP parse took ${avgMs.toStringAsFixed(2)}ms (target < 25ms)');
    });

    test('Database Insert Benchmark: reminder transaction insertion is < 50ms', () async {
      // Warm-up insert
      final warmupReminder = Reminder(
        id: 'warmup_1',
        title: 'Warmup',
        intentType: IntentType.general,
        status: ReminderStatus.pending,
        snoozeCount: 0,
        snoozeDurationMinutes: 10,
        depth: 0,
        version: 1,
        createdAt: clock.now(),
        updatedAt: clock.now(),
        isDeleted: false,
      );
      final warmupTrigger = Trigger(
        id: 'trig_warmup',
        reminderId: 'warmup_1',
        triggerType: TriggerType.scheduledTime,
        scheduledTimeUtc: clock.now().add(const Duration(hours: 1)),
        scheduledTimeTimezone: 'UTC',
        notificationScheduled: false,
        deliveryStatus: DeliveryStatus.scheduled,
      );
      await repo.insertRaw(warmupReminder, warmupTrigger, null);

      const count = 20;
      final latencies = <int>[];

      for (var i = 0; i < count; i++) {
        final reminder = Reminder(
          id: 'bench_rem_$i',
          title: 'Benchmark Task $i',
          intentType: IntentType.call,
          status: ReminderStatus.pending,
          snoozeCount: 0,
          snoozeDurationMinutes: 10,
          depth: 0,
          version: 1,
          createdAt: clock.now(),
          updatedAt: clock.now(),
          isDeleted: false,
        );
        final trigger = Trigger(
          id: 'trig_bench_$i',
          reminderId: 'bench_rem_$i',
          triggerType: TriggerType.scheduledTime,
          scheduledTimeUtc: clock.now().add(Duration(days: i + 1)),
          scheduledTimeTimezone: 'UTC',
          notificationScheduled: true,
          notificationId: 1000 + i,
          deliveryStatus: DeliveryStatus.scheduled,
        );
        final action = Action(
          id: 'act_bench_$i',
          reminderId: 'bench_rem_$i',
          actionType: ActionType.call,
          targetValue: '+1234567890',
        );

        final watch = Stopwatch()..start();
        await repo.insertRaw(reminder, trigger, action);
        watch.stop();

        latencies.add(watch.elapsedMilliseconds);
        expect(
          watch.elapsedMilliseconds,
          lessThan(50),
          reason: 'Insert took ${watch.elapsedMilliseconds}ms (budget < 50ms)',
        );
      }

      final avgLatency = latencies.reduce((a, b) => a + b) / count;
      expect(avgLatency, lessThan(15), reason: 'Average DB insert latency is ${avgLatency.toStringAsFixed(2)}ms');
    });

    test('Reactive Stream Benchmark: Drift stream query update latency is < 100ms', () async {
      final stream = repo.watchPending();
      final emissions = <List<Reminder>>[];
      final sub = stream.listen(emissions.add);

      // Wait for initial emission
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final watch = Stopwatch()..start();
      final reminder = Reminder(
        id: 'reactive_1',
        title: 'Reactive Test',
        intentType: IntentType.general,
        status: ReminderStatus.pending,
        snoozeCount: 0,
        snoozeDurationMinutes: 10,
        depth: 0,
        version: 1,
        createdAt: clock.now(),
        updatedAt: clock.now(),
        isDeleted: false,
      );
      final trigger = Trigger(
        id: 'trig_reactive_1',
        reminderId: 'reactive_1',
        triggerType: TriggerType.scheduledTime,
        scheduledTimeUtc: clock.now().add(const Duration(hours: 2)),
        scheduledTimeTimezone: 'UTC',
        notificationScheduled: false,
        deliveryStatus: DeliveryStatus.scheduled,
      );

      await repo.insertRaw(reminder, trigger, null);

      // Await emission
      while (emissions.isEmpty || !emissions.last.any((r) => r.id == 'reactive_1')) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        if (watch.elapsedMilliseconds > 500) break;
      }
      watch.stop();
      await sub.cancel();

      expect(emissions.last.any((r) => r.id == 'reactive_1'), isTrue);
      expect(
        watch.elapsedMilliseconds,
        lessThan(100),
        reason: 'Reactive stream update took ${watch.elapsedMilliseconds}ms (budget < 100ms)',
      );
    });

    test('Contact Resolution Benchmark: resolving against contact list is < 50ms', () async {
      // Build 500 synthetic contacts
      final largeContactList = List.generate(
        500,
        (i) => ResolvedContact(
          platformId: 'contact_$i',
          displayName: 'Contact Name $i',
          phoneNumber: '+1555${i.toString().padLeft(6, '0')}',
        ),
      );

      final largeBridge = FakeContactBridge(largeContactList);
      final useCase = ResolveContactsUseCase(contactBridge: largeBridge);

      final watch = Stopwatch()..start();
      final matches = await useCase.execute('Contact Name 342');
      watch.stop();

      expect(matches, isNotEmpty);
      expect(matches.first.platformId, equals('contact_342'));
      expect(
        watch.elapsedMilliseconds,
        lessThan(50),
        reason: 'Contact resolution on 500 contacts took ${watch.elapsedMilliseconds}ms (budget < 50ms)',
      );
    });

    test('Database Indices Verification: verifies required performance indices exist', () async {
      final rows = await db
          .customSelect(
            "SELECT name, tbl_name, sql FROM sqlite_master WHERE type = 'index' AND name NOT LIKE 'sqlite_%';",
          )
          .get();

      final indexNames = rows.map((r) => r.read<String>('name')).toSet();

      // Required performance indices from ARCHITECTURE.md §7.2 and TASK-124
      expect(indexNames, contains('idx_reminder_status'));
      expect(indexNames, contains('idx_reminder_parent'));
      expect(indexNames, contains('idx_trigger_scheduled_time'));
      expect(indexNames, contains('idx_trigger_notification_scheduled'));
      expect(indexNames, contains('idx_trigger_delivery_status'));
    });
  });
}
