/// Represents a contact resolved against the on-device address book.
class ResolvedContact {
  final String platformId;
  final String displayName;
  final String? phoneNumber;
  final List<String> allPhoneNumbers;

  const ResolvedContact({
    required this.platformId,
    required this.displayName,
    this.phoneNumber,
    this.allPhoneNumbers = const [],
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResolvedContact &&
          runtimeType == other.runtimeType &&
          platformId == other.platformId &&
          displayName == other.displayName &&
          phoneNumber == other.phoneNumber;

  @override
  int get hashCode => platformId.hashCode ^ displayName.hashCode ^ phoneNumber.hashCode;

  @override
  String toString() => 'ResolvedContact(platformId: $platformId, displayName: $displayName, phone: $phoneNumber)';
}
