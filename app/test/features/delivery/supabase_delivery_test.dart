import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/core/money/money.dart';
import 'package:zaba/features/delivery/data/demo_zones.dart';
import 'package:zaba/features/delivery/data/supabase_delivery_slot_service.dart';
import 'package:zaba/features/delivery/data/supabase_delivery_zone_repository.dart';
import 'package:zaba/features/delivery/domain/delivery_zone.dart';

void main() {
  group('zones', () {
    Map<String, dynamic> row({Object? freeFrom = 15000}) => {
      'id': 'inner',
      'name': 'Belső kerületek',
      'delivery_fee_huf': 990,
      'min_order_huf': 3500,
      'free_delivery_from_huf': freeFrom,
      'eta_min_minutes': 35,
      'eta_max_minutes': 50,
      'is_estimate_default': true,
      'delivery_zone_prefixes': [
        {'prefix': '105'},
        {'prefix': '106'},
      ],
    };

    test('a zone row becomes a zone with its prefixes', () {
      final (:zone, :isEstimateDefault) = zoneRowFromJson(row());

      expect(zone.id, 'inner');
      expect(zone.postalPrefixes, {'105', '106'});
      expect(zone.deliveryFee, const Money(990));
      expect(zone.minOrder, const Money(3500));
      expect(zone.freeDeliveryFrom, const Money(15000));
      expect(zone.etaMinMinutes, 35);
      expect(zone.etaMaxMinutes, 50);
      expect(isEstimateDefault, isTrue);
    });

    test('a zone without a free-delivery threshold has none', () {
      expect(
        zoneRowFromJson(row(freeFrom: null)).zone.freeDeliveryFrom,
        isNull,
      );
    });

    test('zoneServing matches on the first three digits', () {
      expect(zoneServing(demoZones, '1051'), innerZone);
      expect(zoneServing(demoZones, '1039'), outerZone);
      expect(zoneServing(demoZones, '2000'), isNull);
      expect(zoneServing(demoZones, '10'), isNull);
      expect(zoneServing(demoZones, ''), isNull);
    });
  });

  group('slots', () {
    Map<String, dynamic> slot(String id, String start, String end) => {
      'slot_id': id,
      'starts_at': start,
      'ends_at': end,
      'remaining': 10,
    };

    test('slots are grouped into days, earliest first, whatever the order', () {
      final days = deliveryDaysFromRows([
        slot('c', '2026-10-22T10:00:00+00:00', '2026-10-22T11:00:00+00:00'),
        slot('a', '2026-10-21T10:00:00+00:00', '2026-10-21T11:00:00+00:00'),
        slot('b', '2026-10-21T11:00:00+00:00', '2026-10-21T12:00:00+00:00'),
      ]);

      expect(days, hasLength(2));
      expect(days[0].slots.map((s) => s.id), ['a', 'b']);
      expect(days[1].slots.map((s) => s.id), ['c']);
      expect(days[0].date.isBefore(days[1].date), isTrue);
    });

    test('the server\'s UTC times become the same instants', () {
      final day = deliveryDaysFromRows([
        slot('a', '2026-10-21T10:00:00+00:00', '2026-10-21T11:00:00+00:00'),
      ]).single;

      expect(
        day.slots.single.start.isAtSameMomentAs(DateTime.utc(2026, 10, 21, 10)),
        isTrue,
      );
      expect(
        day.slots.single.end.difference(day.slots.single.start).inMinutes,
        60,
      );
    });

    test('no slots is no days', () {
      expect(deliveryDaysFromRows([]), isEmpty);
    });
  });
}
