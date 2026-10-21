import '../../../core/money/money.dart';

/// A group of Budapest districts with the same delivery terms. Zones are
/// matched on the first three characters of the postal code ("1" + the
/// two-digit district number), e.g. "105" is district V.
class DeliveryZone {
  const DeliveryZone({
    required this.id,
    required this.name,
    required this.postalPrefixes,
    required this.deliveryFee,
    required this.minOrder,
    required this.etaMinMinutes,
    required this.etaMaxMinutes,
    this.freeDeliveryFrom,
  });

  final String id;
  final String name;
  final Set<String> postalPrefixes;
  final Money deliveryFee;
  final Money minOrder;
  final int etaMinMinutes;
  final int etaMaxMinutes;

  /// Order value from which delivery is free; null if it never is.
  final Money? freeDeliveryFrom;
}

/// The zone of [zones] that serves [postalCode] (matched on its first three
/// characters), or null if the address is outside the delivery area. The server
/// decides again when it prices and accepts an order; this only lets the app
/// answer before asking.
DeliveryZone? zoneServing(Iterable<DeliveryZone> zones, String postalCode) {
  if (postalCode.length < 3) {
    return null;
  }
  final prefix = postalCode.substring(0, 3);
  for (final zone in zones) {
    if (zone.postalPrefixes.contains(prefix)) {
      return zone;
    }
  }
  return null;
}
