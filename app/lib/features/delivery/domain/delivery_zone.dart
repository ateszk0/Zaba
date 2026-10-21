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
