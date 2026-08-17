import 'dart:io';
import 'package:flutter/services.dart';
import '../../domain/entities/reminder.dart';
import 'notification_bridge.dart';

/// Production [NotificationBridge] implementation using native Flutter [MethodChannel].
class MethodChannelNotificationBridge implements NotificationBridge {
  static const MethodChannel _channel = MethodChannel('com.katala.app/notifications');

  @override
  int get maxPendingNotifications => Platform.isIOS ? 64 : 500;

  @override
  Future<void> configureCategories() async {
    try {
      await _channel.invokeMethod<bool>('configureCategories');
    } catch (_) {}
  }

  @override
  Future<void> playSaveSound() async {
    try {
      await _channel.invokeMethod<bool>('playSaveSound');
    } catch (_) {}
  }

  Map<String, dynamic> _reminderToMap(Reminder reminder) {
    final trigger = reminder.trigger;
    final action = reminder.action;

    return {
      'id': reminder.id,
      'title': reminder.title,
      'notes': reminder.notes,
      'intentType': reminder.intentType.name,
      'scheduledTimeUtc': trigger?.scheduledTimeUtc.toUtc().toIso8601String(),
      'notificationId': trigger?.notificationId ?? (reminder.id.hashCode & 0x7FFFFFFF),
      'action': action != null
          ? {
              'actionType': action.actionType.name,
              'target': action.targetValue,
            }
          : null,
    };
  }

  @override
  Future<int> schedule(Reminder reminder) async {
    final fallbackId = reminder.trigger?.notificationId ?? (reminder.id.hashCode & 0x7FFFFFFF);
    final trigger = reminder.trigger;
    final isEligible = trigger == null ||
        trigger.scheduledTimeUtc.isAfter(DateTime.now().toUtc()) ||
        (trigger.firedAt == null && trigger.scheduledTimeUtc.isAfter(DateTime.now().toUtc().subtract(const Duration(minutes: 2))));
    if (!isEligible) {
      return fallbackId;
    }
    try {
      final result = await _channel.invokeMethod<int>(
        'schedule',
        _reminderToMap(reminder),
      );
      return result ?? fallbackId;
    } catch (_) {
      return fallbackId;
    }
  }

  @override
  Future<void> cancel(int notificationId) async {
    try {
      await _channel.invokeMethod<bool>('cancel', {
        'notificationId': notificationId,
      });
    } catch (_) {}
  }

  @override
  Future<void> cancelForReminder(String reminderId) async {
    try {
      await _channel.invokeMethod<bool>('cancelForReminder', {
        'reminderId': reminderId,
      });
    } catch (_) {}
  }

  @override
  Future<List<int>> getScheduledIds() async {
    try {
      final result = await _channel.invokeListMethod<int>('getScheduledIds');
      return result ?? [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<ReconciliationResult> reconcile({
    required List<Reminder> toSchedule,
    required List<int> knownIds,
  }) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('reconcile', {
        'toSchedule': toSchedule.map(_reminderToMap).toList(),
        'knownIds': knownIds,
      });
      if (result != null) {
        return ReconciliationResult(
          scheduledIds: (result['scheduledIds'] as List<dynamic>?)?.cast<String>() ?? [],
          failedIds: (result['failedIds'] as List<dynamic>?)?.cast<String>() ?? [],
          cancelledIds: (result['cancelledIds'] as List<dynamic>?)?.cast<int>() ?? [],
          errors: (result['errors'] as List<dynamic>?)?.cast<String>() ?? [],
        );
      }
    } catch (e) {
      return ReconciliationResult(errors: [e.toString()]);
    }
    return const ReconciliationResult();
  }
}
