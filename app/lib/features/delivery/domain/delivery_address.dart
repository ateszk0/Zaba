class DeliveryAddress {
  const DeliveryAddress({required this.postalCode, required this.street});

  final String postalCode;

  /// Street and house number, as typed.
  final String street;
}
