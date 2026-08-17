/// Notification categories corresponding to reminder intent types.
enum NotificationCategory {
  general('REMINDER_GENERAL'),
  call('REMINDER_CALL'),
  text('REMINDER_TEXT'),
  url('REMINDER_URL');

  final String value;
  const NotificationCategory(this.value);

  static NotificationCategory fromValue(String value) {
    return NotificationCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Unknown NotificationCategory value: $value'),
    );
  }
}
