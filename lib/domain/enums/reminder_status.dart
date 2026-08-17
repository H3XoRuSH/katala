/// Status of a reminder in the state machine and database.
enum ReminderStatus {
  pending('PENDING'),
  completed('COMPLETED'),
  snoozed('SNOOZED'),
  dismissed('DISMISSED');

  final String value;
  const ReminderStatus(this.value);

  static ReminderStatus fromValue(String value) {
    return ReminderStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Unknown ReminderStatus value: $value'),
    );
  }
}
