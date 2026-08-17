import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/database.dart';
import '../data/repositories/reminder_repository.dart';
import '../data/repositories/reminder_repository_impl.dart';
import '../domain/conflict_detector.dart';
import '../domain/entities/reminder.dart';
import '../domain/nlp/clock.dart';
import '../domain/nlp/nlp_pipeline.dart';
import '../platform/bridges/action_bridge.dart';
import '../platform/bridges/contact_bridge.dart';
import '../platform/bridges/method_channel_action_bridge.dart';
import '../platform/bridges/method_channel_contact_bridge.dart';
import '../platform/bridges/method_channel_notification_bridge.dart';
import '../platform/bridges/method_channel_speech_bridge.dart';
import '../platform/bridges/notification_bridge.dart';
import '../platform/bridges/speech_bridge.dart';
import 'use_cases/complete_reminder_use_case.dart';
import 'use_cases/create_reminder_use_case.dart';
import 'use_cases/delete_reminder_use_case.dart';
import 'use_cases/edit_reminder_use_case.dart';
import 'use_cases/handle_notification_action_use_case.dart';
import 'use_cases/reconcile_notifications_use_case.dart';
import 'use_cases/resolve_contacts_use_case.dart';
import 'use_cases/snooze_reminder_use_case.dart';

// ----------------------------------------------------------------------
// Core Infrastructure Providers (Overridable)
// ----------------------------------------------------------------------

final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('databaseProvider must be overridden in ProviderScope');
});

final clockProvider = Provider<Clock>((ref) {
  return const SystemClock();
});

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepositoryImpl(ref.watch(databaseProvider));
});

final conflictDetectorProvider = Provider<ConflictDetector>((ref) {
  return const ConflictDetector();
});

final nlpPipelineProvider = Provider<NlpPipeline>((ref) {
  return const NlpPipeline();
});

final speechBridgeProvider = Provider<SpeechBridge>((ref) {
  return MethodChannelSpeechBridge();
});

final notificationBridgeProvider = Provider<NotificationBridge>((ref) {
  return MethodChannelNotificationBridge();
});

final contactBridgeProvider = Provider<ContactBridge>((ref) {
  return MethodChannelContactBridge();
});

final actionBridgeProvider = Provider<ActionBridge>((ref) {
  return MethodChannelActionBridge();
});

// ----------------------------------------------------------------------
// Application Use Case Providers
// ----------------------------------------------------------------------

final createReminderUseCaseProvider = Provider<CreateReminderUseCase>((ref) {
  return CreateReminderUseCase(
    nlpPipeline: ref.watch(nlpPipelineProvider),
    contactBridge: ref.watch(contactBridgeProvider),
    conflictDetector: ref.watch(conflictDetectorProvider),
    repository: ref.watch(reminderRepositoryProvider),
    notificationBridge: ref.watch(notificationBridgeProvider),
    clock: ref.watch(clockProvider),
  );
});

final completeReminderUseCaseProvider = Provider<CompleteReminderUseCase>((ref) {
  return CompleteReminderUseCase(
    repository: ref.watch(reminderRepositoryProvider),
    notificationBridge: ref.watch(notificationBridgeProvider),
    clock: ref.watch(clockProvider),
  );
});

final snoozeReminderUseCaseProvider = Provider<SnoozeReminderUseCase>((ref) {
  return SnoozeReminderUseCase(
    repository: ref.watch(reminderRepositoryProvider),
    notificationBridge: ref.watch(notificationBridgeProvider),
    clock: ref.watch(clockProvider),
  );
});

final deleteReminderUseCaseProvider = Provider<DeleteReminderUseCase>((ref) {
  return DeleteReminderUseCase(
    repository: ref.watch(reminderRepositoryProvider),
    notificationBridge: ref.watch(notificationBridgeProvider),
    clock: ref.watch(clockProvider),
  );
});

final undoDeleteReminderUseCaseProvider = Provider<UndoDeleteReminderUseCase>((ref) {
  return UndoDeleteReminderUseCase(
    repository: ref.watch(reminderRepositoryProvider),
    notificationBridge: ref.watch(notificationBridgeProvider),
    clock: ref.watch(clockProvider),
  );
});

final editReminderUseCaseProvider = Provider<EditReminderUseCase>((ref) {
  return EditReminderUseCase(
    repository: ref.watch(reminderRepositoryProvider),
    notificationBridge: ref.watch(notificationBridgeProvider),
    clock: ref.watch(clockProvider),
  );
});

final handleNotificationActionUseCaseProvider = Provider<HandleNotificationActionUseCase>((ref) {
  return HandleNotificationActionUseCase(
    completeReminderUseCase: ref.watch(completeReminderUseCaseProvider),
    snoozeReminderUseCase: ref.watch(snoozeReminderUseCaseProvider),
    actionBridge: ref.watch(actionBridgeProvider),
    repository: ref.watch(reminderRepositoryProvider),
  );
});

final reconcileNotificationsUseCaseProvider = Provider<ReconcileNotificationsUseCase>((ref) {
  return ReconcileNotificationsUseCase(
    repository: ref.watch(reminderRepositoryProvider),
    notificationBridge: ref.watch(notificationBridgeProvider),
    clock: ref.watch(clockProvider),
  );
});

final resolveContactsUseCaseProvider = Provider<ResolveContactsUseCase>((ref) {
  return ResolveContactsUseCase(
    contactBridge: ref.watch(contactBridgeProvider),
  );
});

// ----------------------------------------------------------------------
// Reactive Drift Stream Providers
// ----------------------------------------------------------------------

final pendingRemindersStreamProvider = StreamProvider<List<Reminder>>((ref) {
  return ref.watch(reminderRepositoryProvider).watchPending();
});

final allRemindersStreamProvider = StreamProvider<List<Reminder>>((ref) {
  return ref.watch(reminderRepositoryProvider).watchAll();
});
