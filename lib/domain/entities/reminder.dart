import '../enums/intent_type.dart';
import '../enums/reminder_status.dart';
import 'action.dart';
import 'trigger.dart';

/// Core domain entity representing a reminder with optimistic locking and full lifecycle state.
class Reminder {
  final String id;
  final String title;
  final String? notes;
  final IntentType intentType;
  final ReminderStatus status;
  final int snoozeCount;
  final int snoozeDurationMinutes;
  final String? parentReminderId;
  final int depth;
  final int version;
  final String? originalTranscript;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final Trigger? trigger;
  final Action? action;

  const Reminder({
    required this.id,
    required this.title,
    this.notes,
    this.intentType = IntentType.general,
    this.status = ReminderStatus.pending,
    this.snoozeCount = 0,
    this.snoozeDurationMinutes = 10,
    this.parentReminderId,
    this.depth = 0,
    this.version = 1,
    this.originalTranscript,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.trigger,
    this.action,
  });

  Reminder copyWith({
    String? id,
    String? title,
    String? notes,
    IntentType? intentType,
    ReminderStatus? status,
    int? snoozeCount,
    int? snoozeDurationMinutes,
    String? parentReminderId,
    int? depth,
    int? version,
    String? originalTranscript,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    Trigger? trigger,
    Action? action,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      intentType: intentType ?? this.intentType,
      status: status ?? this.status,
      snoozeCount: snoozeCount ?? this.snoozeCount,
      snoozeDurationMinutes: snoozeDurationMinutes ?? this.snoozeDurationMinutes,
      parentReminderId: parentReminderId ?? this.parentReminderId,
      depth: depth ?? this.depth,
      version: version ?? this.version,
      originalTranscript: originalTranscript ?? this.originalTranscript,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      trigger: trigger ?? this.trigger,
      action: action ?? this.action,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Reminder &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          notes == other.notes &&
          intentType == other.intentType &&
          status == other.status &&
          snoozeCount == other.snoozeCount &&
          snoozeDurationMinutes == other.snoozeDurationMinutes &&
          parentReminderId == other.parentReminderId &&
          depth == other.depth &&
          version == other.version &&
          originalTranscript == other.originalTranscript &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          completedAt == other.completedAt &&
          isDeleted == other.isDeleted &&
          deletedAt == other.deletedAt &&
          trigger == other.trigger &&
          action == other.action;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      notes.hashCode ^
      intentType.hashCode ^
      status.hashCode ^
      snoozeCount.hashCode ^
      snoozeDurationMinutes.hashCode ^
      parentReminderId.hashCode ^
      depth.hashCode ^
      version.hashCode ^
      originalTranscript.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      completedAt.hashCode ^
      isDeleted.hashCode ^
      deletedAt.hashCode ^
      trigger.hashCode ^
      action.hashCode;

  @override
  String toString() =>
      'Reminder(id: $id, title: "$title", status: $status, version: $version, snoozeCount: $snoozeCount)';
}
