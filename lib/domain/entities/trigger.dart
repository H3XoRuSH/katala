import '../enums/delivery_status.dart';
import '../enums/trigger_type.dart';

/// Trigger configuration and notification tracking for a reminder.
class Trigger {
  final String id;
  final String reminderId;
  final TriggerType triggerType;
  final DateTime scheduledTimeUtc;
  final String scheduledTimeTimezone;
  final bool notificationScheduled;
  final int? notificationId;
  final DateTime? firedAt;
  final DeliveryStatus deliveryStatus;
  final String? recurrenceRule;

  const Trigger({
    required this.id,
    required this.reminderId,
    this.triggerType = TriggerType.scheduledTime,
    required this.scheduledTimeUtc,
    this.scheduledTimeTimezone = 'UTC',
    this.notificationScheduled = false,
    this.notificationId,
    this.firedAt,
    this.deliveryStatus = DeliveryStatus.scheduled,
    this.recurrenceRule,
  });

  Trigger copyWith({
    String? id,
    String? reminderId,
    TriggerType? triggerType,
    DateTime? scheduledTimeUtc,
    String? scheduledTimeTimezone,
    bool? notificationScheduled,
    int? notificationId,
    DateTime? firedAt,
    DeliveryStatus? deliveryStatus,
    String? recurrenceRule,
  }) {
    return Trigger(
      id: id ?? this.id,
      reminderId: reminderId ?? this.reminderId,
      triggerType: triggerType ?? this.triggerType,
      scheduledTimeUtc: scheduledTimeUtc ?? this.scheduledTimeUtc,
      scheduledTimeTimezone: scheduledTimeTimezone ?? this.scheduledTimeTimezone,
      notificationScheduled: notificationScheduled ?? this.notificationScheduled,
      notificationId: notificationId ?? this.notificationId,
      firedAt: firedAt ?? this.firedAt,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Trigger &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          reminderId == other.reminderId &&
          triggerType == other.triggerType &&
          scheduledTimeUtc == other.scheduledTimeUtc &&
          scheduledTimeTimezone == other.scheduledTimeTimezone &&
          notificationScheduled == other.notificationScheduled &&
          notificationId == other.notificationId &&
          firedAt == other.firedAt &&
          deliveryStatus == other.deliveryStatus &&
          recurrenceRule == other.recurrenceRule;

  @override
  int get hashCode =>
      id.hashCode ^
      reminderId.hashCode ^
      triggerType.hashCode ^
      scheduledTimeUtc.hashCode ^
      scheduledTimeTimezone.hashCode ^
      notificationScheduled.hashCode ^
      notificationId.hashCode ^
      firedAt.hashCode ^
      deliveryStatus.hashCode ^
      recurrenceRule.hashCode;

  @override
  String toString() =>
      'Trigger(id: $id, reminderId: $reminderId, type: $triggerType, timeUtc: $scheduledTimeUtc, tz: $scheduledTimeTimezone, scheduled: $notificationScheduled, delivery: $deliveryStatus)';
}
