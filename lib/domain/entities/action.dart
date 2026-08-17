import '../enums/action_type.dart';

/// Action details associated with a reminder.
class Action {
  final String id;
  final String reminderId;
  final ActionType actionType;
  final String? targetValue;
  final String? contactName;
  final String? contactPhone;
  final String? contactId;

  const Action({
    required this.id,
    required this.reminderId,
    this.actionType = ActionType.general,
    this.targetValue,
    this.contactName,
    this.contactPhone,
    this.contactId,
  });

  Action copyWith({
    String? id,
    String? reminderId,
    ActionType? actionType,
    String? targetValue,
    String? contactName,
    String? contactPhone,
    String? contactId,
  }) {
    return Action(
      id: id ?? this.id,
      reminderId: reminderId ?? this.reminderId,
      actionType: actionType ?? this.actionType,
      targetValue: targetValue ?? this.targetValue,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      contactId: contactId ?? this.contactId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Action &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          reminderId == other.reminderId &&
          actionType == other.actionType &&
          targetValue == other.targetValue &&
          contactName == other.contactName &&
          contactPhone == other.contactPhone &&
          contactId == other.contactId;

  @override
  int get hashCode =>
      id.hashCode ^
      reminderId.hashCode ^
      actionType.hashCode ^
      targetValue.hashCode ^
      contactName.hashCode ^
      contactPhone.hashCode ^
      contactId.hashCode;

  @override
  String toString() =>
      'Action(id: $id, reminderId: $reminderId, type: $actionType, target: $targetValue, contact: $contactName)';
}
