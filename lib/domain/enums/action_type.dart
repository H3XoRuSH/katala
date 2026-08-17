/// Action to perform when a reminder notification is activated or viewed.
enum ActionType {
  call('CALL'),
  text('TEXT'),
  email('EMAIL'),
  openUrl('OPEN_URL'),
  general('GENERAL');

  final String value;
  const ActionType(this.value);

  static ActionType fromValue(String value) {
    return ActionType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Unknown ActionType value: $value'),
    );
  }
}
