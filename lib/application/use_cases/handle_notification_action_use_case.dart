import '../../data/repositories/reminder_repository.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/errors.dart';
import '../../domain/result.dart';
import '../../platform/bridges/action_bridge.dart';
import 'complete_reminder_use_case.dart';
import 'snooze_reminder_use_case.dart';

/// Outcome of handling a notification action.
sealed class NotificationActionResult {
  const NotificationActionResult();

  const factory NotificationActionResult.completed(Reminder reminder) = _CompletedResult;
  const factory NotificationActionResult.snoozed(Reminder reminder) = _SnoozedResult;
  const factory NotificationActionResult.callInitiated(String phoneNumber, Reminder reminder) = _CallInitiatedResult;
  const factory NotificationActionResult.smsInitiated(String phoneNumber, Reminder reminder) = _SmsInitiatedResult;
  const factory NotificationActionResult.urlOpened(String url, Reminder reminder) = _UrlOpenedResult;
  const factory NotificationActionResult.openApp(String reminderId) = _OpenAppResult;
}

class _CompletedResult extends NotificationActionResult {
  final Reminder reminder;
  const _CompletedResult(this.reminder);
}

class _SnoozedResult extends NotificationActionResult {
  final Reminder reminder;
  const _SnoozedResult(this.reminder);
}

class _CallInitiatedResult extends NotificationActionResult {
  final String phoneNumber;
  final Reminder reminder;
  const _CallInitiatedResult(this.phoneNumber, this.reminder);
}

class _SmsInitiatedResult extends NotificationActionResult {
  final String phoneNumber;
  final Reminder reminder;
  const _SmsInitiatedResult(this.phoneNumber, this.reminder);
}

class _UrlOpenedResult extends NotificationActionResult {
  final String url;
  final Reminder reminder;
  const _UrlOpenedResult(this.url, this.reminder);
}

class _OpenAppResult extends NotificationActionResult {
  final String reminderId;
  const _OpenAppResult(this.reminderId);
}

/// Routes notification actions (DONE, SNOOZE, CALL, TEXT, OPEN_LINK, EDIT) to appropriate use cases.
class HandleNotificationActionUseCase {
  final CompleteReminderUseCase completeReminderUseCase;
  final SnoozeReminderUseCase snoozeReminderUseCase;
  final ActionBridge actionBridge;
  final ReminderRepository repository;

  const HandleNotificationActionUseCase({
    required this.completeReminderUseCase,
    required this.snoozeReminderUseCase,
    required this.actionBridge,
    required this.repository,
  });

  /// Executes the requested notification action.
  Future<Result<NotificationActionResult, AppError>> execute(
    String reminderId,
    String actionIdentifier, {
    int? snoozeDurationMinutes,
  }) async {
    final action = actionIdentifier.toUpperCase();

    if (action == 'ACTION_DONE' ||
        action == 'DONE' ||
        action == 'COMPLETE' ||
        action == 'COM.KATALA.APP.ACTION_COMPLETE') {
      final completeResult = await completeReminderUseCase.execute(reminderId);
      return completeResult.map(NotificationActionResult.completed);
    }

    if (action == 'ACTION_SNOOZE' || action == 'SNOOZE' || action == 'COM.KATALA.APP.ACTION_SNOOZE') {
      final snoozeResult = await snoozeReminderUseCase.execute(
        reminderId,
        customDurationMinutes: snoozeDurationMinutes,
      );
      return snoozeResult.map(NotificationActionResult.snoozed);
    }

    if (action == 'ACTION_EDIT' || action == 'EDIT') {
      return Result.success(NotificationActionResult.openApp(reminderId));
    }

    final reminder = await repository.getById(reminderId);
    if (reminder == null) {
      return const Result.failure(PersistenceFailed('Reminder not found'));
    }

    if (action == 'ACTION_CALL' || action == 'CALL' || action == 'CALL_NOW' || action == 'COM.KATALA.APP.ACTION_CALL') {
      final phone = reminder.action?.contactPhone ?? reminder.action?.targetValue;
      if (phone != null && phone.isNotEmpty) {
        await actionBridge.launchDialer(phone);
      }
      final completeResult = await completeReminderUseCase.execute(reminderId);
      return completeResult.map(
        (completed) => NotificationActionResult.callInitiated(phone ?? '', completed),
      );
    }

    if (action == 'ACTION_TEXT' ||
        action == 'TEXT' ||
        action == 'TEXT_NOW' ||
        action == 'SMS' ||
        action == 'ACTION_SMS' ||
        action == 'COM.KATALA.APP.ACTION_SMS') {
      final phone = reminder.action?.contactPhone ?? reminder.action?.targetValue;
      if (phone != null && phone.isNotEmpty) {
        await actionBridge.launchSms(phone);
      }
      final completeResult = await completeReminderUseCase.execute(reminderId);
      return completeResult.map(
        (completed) => NotificationActionResult.smsInitiated(phone ?? '', completed),
      );
    }

    if (action == 'ACTION_URL' ||
        action == 'OPEN_LINK' ||
        action == 'OPEN_URL' ||
        action == 'URL' ||
        action == 'ACTION_OPEN_URL' ||
        action == 'COM.KATALA.APP.ACTION_OPEN_URL') {
      final url = reminder.action?.targetValue;
      if (url != null && url.isNotEmpty) {
        await actionBridge.launchUrl(url);
      }
      final completeResult = await completeReminderUseCase.execute(reminderId);
      return completeResult.map(
        (completed) => NotificationActionResult.urlOpened(url ?? '', completed),
      );
    }

    return const Result.failure(PersistenceFailed('Unknown notification action'));
  }
}
