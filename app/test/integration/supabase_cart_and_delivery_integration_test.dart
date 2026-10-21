@Tags(['integration'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zaba/features/cart/data/in_memory_quote_service.dart';
import 'package:zaba/features/cart/data/supabase_quote_service.dart';
import 'package:zaba/features/cart/domain/cart_quote.dart';
import 'package:zaba/features/cart/domain/quote_service.dart';
import 'package:zaba/features/catalog/data/in_memory_catalog_repository.dart';
import 'package:zaba/features/delivery/data/demo_zones.dart';
import 'package:zaba/features/delivery/data/in_memory_delivery_zone_repository.dart';
import 'package:zaba/features/delivery/data/supabase_delivery_slot_service.dart';
import 'package:zaba/features/delivery/data/supabase_delivery_zone_repository.dart';
import 'package:zaba/features/delivery/domain/delivery_slot.dart';
import 'package:zaba/features/delivery/domain/delivery_zone.dart';

import 'integration_env.dart';

// The pricing, the delivery zones and the delivery slots, from a real Supabase.
// The in-memory services follow the same rules by design, so the same questions
// must get the same answers from both: that is how the Dart copy of the rules
// and the SQL are kept honest.

const catalog = InMemoryCatalogRepository();

String describeQuote(CartQuote q) => [
  'subtotal=${q.subtotal.forint}',
  'fee=${q.deliveryFee.forint}',
  'total=${q.total.forint}',
  'min=${q.minOrder.forint}',
  'free=${q.freeDeliveryFrom?.forint}',
  'estimated=${q.estimated}',
  for (final line in q.lines)
    '${line.product.id}x${line.quantity}@${line.unitPrice.forint}=${line.total.forint}',
].join(' ');

String describeZone(DeliveryZone z) => [
  z.id,
  z.name,
  (z.postalPrefixes.toList()..sort()).join(','),
  z.deliveryFee.forint,
  z.minOrder.forint,
  z.freeDeliveryFrom?.forint,
  z.etaMinMinutes,
  z.etaMaxMinutes,
].join('|');

void main() {
  late SupabaseClient client;

  setUpAll(() {
    // flutter_test answers every HTTP request with an error; this test needs the
    // real network.
    HttpOverrides.global = null;
  });

  setUp(() => client = newIntegrationClient());
  tearDown(() => client.dispose());

  group('pricing', () {
    late SupabaseQuoteService server;
    late InMemoryQuoteService local;

    setUp(() {
      server = SupabaseQuoteService(client, loadProducts: catalog.products);
      local = InMemoryQuoteService(
        catalog: catalog,
        zones: const InMemoryDeliveryZoneRepository(),
      );
    });

    final cases = <String, (Map<String, int>, String?)>{
      'inner zone, under the free-delivery threshold': (
        {'carbonara': 2},
        '1051',
      ),
      'inner zone, over the free-delivery threshold': (
        {'carbonara': 6},
        '1051',
      ),
      'outer zone, which has no free delivery': ({'carbonara': 2}, '1039'),
      'several products': (
        {'carbonara': 1, 'bolognese': 2, 'lemonade': 3},
        '1061',
      ),
      'no address yet (an estimate)': ({'carbonara': 2}, null),
      'an empty cart': (<String, int>{}, '1051'),
    };

    for (final MapEntry(key: name, value: (lines, postalCode))
        in cases.entries) {
      test('$name: the same answer as the Dart rules', () async {
        final fromServer = await server.quote(
          lines: lines,
          postalCode: postalCode,
        );
        final fromDart = await local.quote(
          lines: lines,
          postalCode: postalCode,
        );

        expect(describeQuote(fromServer), describeQuote(fromDart));
      });
    }

    test('the server prices 2 carbonaras to district V at 6 570 Ft', () async {
      final quote = await server.quote(
        lines: {'carbonara': 2},
        postalCode: '1051',
      );
      expect(quote.total.forint, 6570);
      expect(quote.estimated, isFalse);
    });

    test('an address outside the area is refused with its own error', () async {
      for (final postalCode in ['2000', '1239', '12']) {
        await expectLater(
          server.quote(lines: {'carbonara': 1}, postalCode: postalCode),
          throwsA(isA<OutOfDeliveryAreaException>()),
          reason: postalCode,
        );
      }
    });

    test('a product that is not sold is left out of the quote', () async {
      final quote = await server.quote(
        lines: {'carbonara': 1, 'ghost': 2},
        postalCode: '1051',
      );
      expect(quote.lines.map((l) => l.product.id), ['carbonara']);
    });

    test(
      'a line above the limit is refused, the app never sends one',
      () async {
        await expectLater(
          server.quote(lines: {'carbonara': 100}, postalCode: '1051'),
          throwsA(
            isA<PostgrestException>().having(
              (e) => e.message,
              'message',
              'invalid_lines',
            ),
          ),
        );
      },
    );
  }, skip: integrationSkip);

  group('delivery zones', () {
    test('the zones are the demo zones, field for field', () async {
      final zones = SupabaseDeliveryZoneRepository(client);

      for (final demo in demoZones) {
        for (final prefix in demo.postalPrefixes) {
          final found = await zones.zoneForPostalCode('${prefix}1');
          expect(found, isNotNull, reason: prefix);
          expect(describeZone(found!), describeZone(demo), reason: prefix);
        }
      }
      expect(describeZone(await zones.defaultZone()), describeZone(innerZone));
    });

    test('an address outside the area has no zone', () async {
      final zones = SupabaseDeliveryZoneRepository(client);
      expect(await zones.zoneForPostalCode('2000'), isNull);
      expect(await zones.zoneForPostalCode('10'), isNull);
    });
  }, skip: integrationSkip);

  group('delivery slots', () {
    test('a guest cannot list them, a customer can', () async {
      final slots = SupabaseDeliverySlotService(client);
      await expectLater(
        slots.availableDays(now: DateTime.now()),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '42501'),
        ),
      );

      await client.auth.signUp(
        email: 'slots-${DateTime.now().microsecondsSinceEpoch}@example.test',
        password: 'hosszu-jelszo-1',
      );
      final days = await slots.availableDays(now: DateTime.now());

      expect(days, isNotEmpty);
      expect(days.length, lessThanOrEqualTo(3));
      final all = [for (final day in days) ...day.slots];
      final soonest = DateTime.now().add(const Duration(minutes: 40));
      for (final slot in all) {
        expect(slot.id, matches(RegExp(r'^[0-9a-f-]{36}$')));
        expect(slot.end.difference(slot.start).inMinutes, 60);
        expect(slot.start.isAfter(soonest), isTrue);
      }

      expect(await slots.isAvailable(all.first, now: DateTime.now()), isTrue);
      final unknown = all.first.id.replaceRange(0, 8, '00000000');
      expect(
        await slots.isAvailable(
          DeliverySlot(id: unknown, start: all.first.start, end: all.first.end),
          now: DateTime.now(),
        ),
        isFalse,
      );
    });
  }, skip: integrationSkip);
}
