/// Primary intent classified from user reminder input.
enum IntentType {
  general('GENERAL'),
  call('CALL'),
  text('TEXT'),
  email('EMAIL'),
  openUrl('OPEN_URL');

  final String value;
  const IntentType(this.value);

  static IntentType fromValue(String value) {
    return IntentType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Unknown IntentType value: $value'),
    );
  }
}
