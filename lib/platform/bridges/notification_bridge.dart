import '../../domain/entities/reminder.dart';

/// Result summary of an OS notification reconciliation pass.
class ReconciliationResult {
  final List<String> scheduledIds;
  final List<String> failedIds;
  final List<int> cancelledIds;
  final List<String> errors;

  const ReconciliationResult({
    this.scheduledIds = const [],
    this.failedIds = const [],
    this.cancelledIds = const [],
    this.errors = const [],
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReconciliationResult &&
          runtimeType == other.runtimeType &&
          scheduledIds == other.scheduledIds &&
          failedIds == other.failedIds &&
          cancelledIds == other.cancelledIds &&
          errors == other.errors;

  @override
  int get hashCode => scheduledIds.hashCode ^ failedIds.hashCode ^ cancelledIds.hashCode ^ errors.hashCode;

  @override
  String toString() =>
      'ReconciliationResult(scheduled: ${scheduledIds.length}, failed: ${failedIds.length}, cancelled: ${cancelledIds.length}, errors: ${errors.length})';
}

/// Dart abstraction for platform-level local notification scheduling and category registration.
///
/// ## Category Coordination Architecture (M3, L3)
/// - **Native Bridge (Single Source of Truth)**: Registers interactive notification
///   categories on startup before notifications are scheduled (iOS `UNNotificationCategory`, Android `NotificationChannel`).
/// - **Dart Handlers**: Listen for notification action taps via callbacks and route them to [HandleNotificationActionUseCase].
/// - Category and Action identifiers must match across platforms exactly.
abstract class NotificationBridge {
  // Category Identifiers
  static const String categoryGeneral = 'REMINDER_GENERAL';
  static const String categoryCall = 'REMINDER_CALL';
  static const String categoryText = 'REMINDER_TEXT';
  static const String categoryUrl = 'REMINDER_URL';

  // Action Identifiers
  static const String actionDone = 'ACTION_DONE';
  static const String actionSnooze = 'ACTION_SNOOZE';
  static const String actionCall = 'ACTION_CALL';
  static const String actionText = 'ACTION_TEXT';
  static const String actionUrl = 'ACTION_URL';
  static const String actionEdit = 'ACTION_EDIT';

  /// Schedules a system notification for the given [reminder].
  /// Cancels any existing notification for this reminder first (idempotent).
  /// Returns the platform notification ID.
  Future<int> schedule(Reminder reminder);

  /// Cancels a scheduled notification by platform notification ID.
  Future<void> cancel(int notificationId);

  /// Cancels the notification associated with a specific [reminderId].
  Future<void> cancelForReminder(String reminderId);

  /// Queries all currently scheduled OS notification IDs (best-effort).
  Future<List<int>> getScheduledIds();

  /// Reconciles OS notification state with database reminders.
  /// Cancels orphaned notification IDs and schedules missing notifications up to [maxPendingNotifications].
  Future<ReconciliationResult> reconcile({
    required List<Reminder> toSchedule,
    required List<int> knownIds,
  });

  /// Registers interactive notification categories (`general`, `call`, `text`, `url`).
  /// Must be called on app startup before scheduling any notifications.
  Future<void> configureCategories();

  /// Plays the in-app confirmation bird chirp sound on successful reminder save.
  Future<void> playSaveSound();

  /// Maximum pending notifications allowed by the OS (64 on iOS, unlimited/high on Android).
  int get maxPendingNotifications;
}
