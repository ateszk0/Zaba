import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/core/money/money.dart';
import 'package:zaba/features/cart/data/in_memory_quote_service.dart';
import 'package:zaba/features/cart/domain/quote_service.dart';
import 'package:zaba/features/catalog/data/in_memory_catalog_repository.dart';
import 'package:zaba/features/delivery/data/in_memory_delivery_zone_repository.dart';

import '../../support/test_catalog.dart';

void main() {
  const service = InMemoryQuoteService(
    catalog: InMemoryCatalogRepository(
      categoryList: testCategories,
      productList: testProducts,
    ),
    zones: InMemoryDeliveryZoneRepository(),
  );

  test('an empty cart has no fee and zero totals', () async {
    final quote = await service.quote(lines: const {});

    expect(quote.isEmpty, isTrue);
    expect(quote.subtotal, Money.zero);
    expect(quote.deliveryFee, Money.zero);
    expect(quote.total, Money.zero);
  });

  test('prices lines and adds the delivery fee of the zone', () async {
    final quote = await service.quote(
      lines: const {'carbonara': 2, 'lemonade': 1},
      postalCode: '1051',
    );

    expect(quote.subtotal, const Money(2 * 2790 + 790));
    expect(quote.deliveryFee, const Money(990));
    expect(quote.total, const Money(2 * 2790 + 790 + 990));
    expect(quote.itemCount, 3);
    expect(quote.estimated, isFalse);
  });

  test('delivery is free from the threshold of the inner zone', () async {
    final below = await service.quote(
      lines: const {'carbonara': 5},
      postalCode: '1051',
    );
    expect(below.subtotal, const Money(13950));
    expect(below.deliveryFee, const Money(990));
    expect(below.remainingForFreeDelivery, const Money(15000 - 13950));

    final atThreshold = await service.quote(
      lines: const {'carbonara': 5, 'lemonade': 2},
      postalCode: '1051',
    );
    expect(atThreshold.subtotal, const Money(15530));
    expect(atThreshold.deliveryFee, Money.zero);
    expect(atThreshold.remainingForFreeDelivery, isNull);
  });

  test(
    'the outer zone has its own fee and minimum and never gives free delivery',
    () async {
      final quote = await service.quote(
        lines: const {'carbonara': 10},
        postalCode: '1041',
      );

      expect(quote.deliveryFee, const Money(1490));
      expect(quote.minOrder, const Money(5000));
      expect(quote.remainingForFreeDelivery, isNull);
    },
  );

  test('reports how much is missing to the minimum order', () async {
    final short = await service.quote(
      lines: const {'lemonade': 2},
      postalCode: '1051',
    );
    expect(short.minOrderShortfall, const Money(3500 - 1580));
    expect(short.meetsMinOrder, isFalse);

    final enough = await service.quote(
      lines: const {'carbonara': 2},
      postalCode: '1051',
    );
    expect(enough.minOrderShortfall, Money.zero);
    expect(enough.meetsMinOrder, isTrue);
  });

  test(
    'without an address the default zone is used and the quote is an estimate',
    () async {
      final quote = await service.quote(lines: const {'carbonara': 1});

      expect(quote.estimated, isTrue);
      expect(quote.deliveryFee, const Money(990));
    },
  );

  test('an address outside the delivery area is rejected', () async {
    await expectLater(
      service.quote(lines: const {'carbonara': 1}, postalCode: '1181'),
      throwsA(isA<OutOfDeliveryAreaException>()),
    );
    await expectLater(
      service.quote(lines: const {'carbonara': 1}, postalCode: '9999'),
      throwsA(isA<OutOfDeliveryAreaException>()),
    );
  });

  test('unknown products and zero quantities are ignored', () async {
    final quote = await service.quote(
      lines: const {'ghost': 3, 'lemonade': 0, 'carbonara': 1},
      postalCode: '1051',
    );

    expect(quote.lines.map((line) => line.product.id), ['carbonara']);
    expect(quote.subtotal, const Money(2790));
  });
}
