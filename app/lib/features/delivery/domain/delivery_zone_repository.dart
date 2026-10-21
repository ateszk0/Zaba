import 'delivery_zone.dart';

abstract interface class DeliveryZoneRepository {
  /// The zone serving [postalCode], or null if it is outside the delivery area.
  Future<DeliveryZone?> zoneForPostalCode(String postalCode);

  /// The zone assumed for estimates before the customer has given an address.
  Future<DeliveryZone> defaultZone();
}
