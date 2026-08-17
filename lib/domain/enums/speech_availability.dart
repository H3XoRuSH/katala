/// Availability state of on-device speech recognition.
enum SpeechAvailability {
  available('available'),
  unavailable('unavailable'),
  permissionDenied('permissionDenied'),
  notSupported('notSupported');

  final String value;
  const SpeechAvailability(this.value);

  static SpeechAvailability fromValue(String value) {
    return SpeechAvailability.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Unknown SpeechAvailability value: $value'),
    );
  }
}
