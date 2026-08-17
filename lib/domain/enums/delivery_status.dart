/// Observed delivery status of a reminder notification.
enum DeliveryStatus {
  scheduled('scheduled'),
  deliveryUncertain('delivery_uncertain'),
  deliveryMissed('delivery_missed');

  final String value;
  const DeliveryStatus(this.value);

  static DeliveryStatus fromValue(String value) {
    return DeliveryStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Unknown DeliveryStatus value: $value'),
    );
  }
}
