import '../domain/delivery_zone.dart';
import '../domain/delivery_zone_repository.dart';
import 'demo_zones.dart';

class InMemoryDeliveryZoneRepository implements DeliveryZoneRepository {
  const InMemoryDeliveryZoneRepository({
    this.zones = demoZones,
    this.fallbackZone = innerZone,
  });

  final List<DeliveryZone> zones;
  final DeliveryZone fallbackZone;

  @override
  Future<DeliveryZone?> zoneForPostalCode(String postalCode) async =>
      zoneServing(zones, postalCode);

  @override
  Future<DeliveryZone> defaultZone() async => fallbackZone;
}
