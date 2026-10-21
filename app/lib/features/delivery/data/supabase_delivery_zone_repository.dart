import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/money/money.dart';
import '../domain/delivery_zone.dart';
import '../domain/delivery_zone_repository.dart';

/// The delivery zones from Supabase. There are only a few, so they are loaded
/// once and the postal code is matched here; the server checks the address
/// again when it prices and accepts an order. A failed load is not remembered,
/// the next call asks again.
class SupabaseDeliveryZoneRepository implements DeliveryZoneRepository {
  SupabaseDeliveryZoneRepository(this._client);

  final SupabaseClient _client;
  Future<List<ZoneRow>>? _loaded;

  Future<List<ZoneRow>> _zones() async {
    final pending = _loaded ??= _fetch();
    try {
      return await pending;
    } catch (_) {
      _loaded = null;
      rethrow;
    }
  }

  Future<List<ZoneRow>> _fetch() async {
    final rows = await _client
        .from('delivery_zones')
        .select(
          'id, name, delivery_fee_huf, min_order_huf, free_delivery_from_huf, '
          'eta_min_minutes, eta_max_minutes, is_estimate_default, '
          'delivery_zone_prefixes(prefix)',
        )
        .order('sort_order', ascending: true)
        .order('id', ascending: true);
    return rows.map(zoneRowFromJson).toList(growable: false);
  }

  @override
  Future<DeliveryZone?> zoneForPostalCode(String postalCode) async =>
      zoneServing((await _zones()).map((row) => row.zone), postalCode);

  @override
  Future<DeliveryZone> defaultZone() async {
    for (final row in await _zones()) {
      if (row.isEstimateDefault) {
        return row.zone;
      }
    }
    throw StateError('No default delivery zone is configured.');
  }
}

typedef ZoneRow = ({DeliveryZone zone, bool isEstimateDefault});

ZoneRow zoneRowFromJson(Map<String, dynamic> row) {
  final freeFrom = row['free_delivery_from_huf'] as int?;
  final zone = DeliveryZone(
    id: row['id'] as String,
    name: row['name'] as String,
    postalPrefixes: {
      for (final prefix in row['delivery_zone_prefixes'] as List<dynamic>)
        (prefix as Map<String, dynamic>)['prefix'] as String,
    },
    deliveryFee: Money(row['delivery_fee_huf'] as int),
    minOrder: Money(row['min_order_huf'] as int),
    freeDeliveryFrom: freeFrom == null ? null : Money(freeFrom),
    etaMinMinutes: row['eta_min_minutes'] as int,
    etaMaxMinutes: row['eta_max_minutes'] as int,
  );
  return (zone: zone, isEstimateDefault: row['is_estimate_default'] as bool);
}
