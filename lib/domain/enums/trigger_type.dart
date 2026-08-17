/// Type of trigger associated with a reminder.
enum TriggerType {
  scheduledTime('SCHEDULED_TIME'),
  geofence('GEOFENCE');

  final String value;
  const TriggerType(this.value);

  static TriggerType fromValue(String value) {
    return TriggerType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Unknown TriggerType value: $value'),
    );
  }
}
