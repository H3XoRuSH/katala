import 'dart:async';
import '../../data/repositories/reminder_repository.dart';
import '../../domain/enums/delivery_status.dart';
import '../../domain/enums/reminder_status.dart';
import '../../domain/nlp/clock.dart';
import '../../platform/bridges/notification_bridge.dart';

/// Full notification reconciliation engine running on foreground entry and background wakes.
class ReconcileNotificationsUseCase {
  final ReminderRepository repository;
  final NotificationBridge notificationBridge;
  final Clock clock;

  bool _isReconciling = false;
  bool _reconciliationPending = false;

  ReconcileNotificationsUseCase({
    required this.repository,
    required this.notificationBridge,
    required this.clock,
  });

  /// Executes the 5-step reconciliation algorithm (§13.1).
  Future<ReconciliationResult> execute() async {
    if (_isReconciling) {
      _reconciliationPending = true;
      return const ReconciliationResult();
    }

    _isReconciling = true;
    final scheduledIds = <String>[];
    final failedIds = <String>[];
    final cancelledIds = <int>[];
    final errors = <String>[];

    try {
      // 1. Cancel orphaned OS notifications
      final osNotificationIds = await notificationBridge.getScheduledIds();
      for (final id in osNotificationIds) {
        final matchingReminders = await repository.getByNotificationId(id);
        final isOrphan = matchingReminders.isEmpty ||
            matchingReminders.any(
                (r) => r.isDeleted || r.status == ReminderStatus.completed || r.status == ReminderStatus.dismissed);

        if (isOrphan) {
          try {
            await notificationBridge.cancel(id);
            cancelledIds.add(id);
            for (final r in matchingReminders) {
              await repository.updateTriggerScheduling(r.id, false, null);
            }
          } catch (e) {
            errors.add('Failed to cancel orphaned notification $id: $e');
          }
        }
      }

      // 2. Schedule missing notifications up to OS limit
      final now = clock.now();
      final limit = notificationBridge.maxPendingNotifications;
      final pendingReminders = await repository.getPendingSortedByTime(limit: limit);

      for (final reminder in pendingReminders) {
        final trigger = reminder.trigger;
        final isEligible = trigger != null &&
            !trigger.notificationScheduled &&
            (trigger.scheduledTimeUtc.isAfter(now.toUtc()) ||
                (trigger.firedAt == null && trigger.scheduledTimeUtc.isAfter(now.toUtc().subtract(const Duration(minutes: 2)))));
        if (isEligible) {
          try {
            // Idempotent duplicate prevention: cancel old notification before scheduling new
            if (reminder.trigger?.notificationId != null) {
              await notificationBridge.cancel(reminder.trigger!.notificationId!);
            } else {
              await notificationBridge.cancelForReminder(reminder.id);
            }
            final notificationId = await notificationBridge.schedule(reminder);
            await repository.updateTriggerScheduling(reminder.id, true, notificationId);
            scheduledIds.add(reminder.id);
          } catch (e) {
            failedIds.add(reminder.id);
            errors.add('Failed to schedule notification for reminder ${reminder.id}: $e');
          }
        }
      }

      // 3. Detect missed deliveries (with 2-minute grace period for active alarms)
      final lastReconciledStr = await repository.getMetadata('last_reconciled_at');
      if (lastReconciledStr != null) {
        final lastReconciled = DateTime.tryParse(lastReconciledStr);
        final missedCutoff = now.subtract(const Duration(minutes: 2));
        if (lastReconciled != null && missedCutoff.isAfter(lastReconciled)) {
          final missedReminders = await repository.getByTimeRange(lastReconciled, missedCutoff);
          for (final reminder in missedReminders) {
            if ((reminder.status == ReminderStatus.pending || reminder.status == ReminderStatus.snoozed) &&
                !reminder.isDeleted) {
              final trigger = reminder.trigger;
              if (trigger != null && trigger.deliveryStatus == DeliveryStatus.scheduled && trigger.firedAt == null) {
                await repository.updateTriggerDeliveryStatus(
                  reminder.id,
                  DeliveryStatus.deliveryUncertain,
                );
              }
            }
          }
        }
      }

      // 4. Update reconciliation timestamp
      await repository.setMetadata('last_reconciled_at', now.toUtc().toIso8601String());

      // 5. Hard-delete old soft-deleted reminders (> 30 days)
      await repository.hardDeleteOlderThan(now.subtract(const Duration(days: 30)));
    } finally {
      _isReconciling = false;
      if (_reconciliationPending) {
        _reconciliationPending = false;
        // Schedule follow-up pass asynchronously
        unawaited(execute());
      }
    }

    return ReconciliationResult(
      scheduledIds: scheduledIds,
      failedIds: failedIds,
      cancelledIds: cancelledIds,
      errors: errors,
    );
  }
}
