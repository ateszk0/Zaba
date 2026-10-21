import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/core/money/money.dart';
import 'package:zaba/features/cart/data/supabase_quote_service.dart';
import 'package:zaba/features/cart/domain/quote_service.dart';
import 'package:zaba/features/catalog/domain/product.dart';

import '../../support/test_catalog.dart';

Map<String, Product> get menu => {
  for (final product in testProducts) product.id: product,
};

/// The shape `quote_cart` answers with.
Map<String, dynamic> quoteJson({
  List<Map<String, dynamic>>? lines,
  Object? freeFrom = 15000,
  bool estimated = false,
}) => {
  'lines':
      lines ??
      [
        {
          'product_id': 'carbonara',
          'name': 'Spagetti carbonara',
          'quantity': 2,
          'unit_price_huf': 2790,
          'vat_rate_percent': 27,
          'line_total_huf': 5580,
        },
      ],
  'subtotal_huf': 5580,
  'delivery_fee_huf': 990,
  'total_huf': 6570,
  'min_order_huf': 3500,
  'free_delivery_from_huf': freeFrom,
  'zone_id': 'inner',
  'estimated': estimated,
};

void main() {
  test('the numbers of the quote are the server\'s', () {
    final quote = cartQuoteFromJson(quoteJson(), menu);

    expect(quote.subtotal, const Money(5580));
    expect(quote.deliveryFee, const Money(990));
    expect(quote.total, const Money(6570));
    expect(quote.minOrder, const Money(3500));
    expect(quote.freeDeliveryFrom, const Money(15000));
    expect(quote.estimated, isFalse);
    expect(quote.itemCount, 2);
  });

  test('a line shows the server\'s price, not the menu\'s', () {
    final json = quoteJson(
      lines: [
        {
          'product_id': 'carbonara',
          'name': 'Spagetti carbonara',
          'quantity': 2,
          // The price changed after the menu was loaded.
          'unit_price_huf': 2990,
          'vat_rate_percent': 27,
          'line_total_huf': 5980,
        },
      ],
    );

    final line = cartQuoteFromJson(json, menu).lines.single;

    expect(line.product, carbonara);
    expect(line.unitPrice, const Money(2990));
    expect(line.total, const Money(5980));
  });

  test('no free-delivery threshold and an estimate come through', () {
    final quote = cartQuoteFromJson(
      quoteJson(freeFrom: null, estimated: true),
      menu,
    );

    expect(quote.freeDeliveryFrom, isNull);
    expect(quote.remainingForFreeDelivery, isNull);
    expect(quote.estimated, isTrue);
  });

  test('an empty cart is an empty quote', () {
    final quote = cartQuoteFromJson(quoteJson(lines: []), menu);

    expect(quote.isEmpty, isTrue);
  });

  test('a product the menu does not know is reported, not hidden', () {
    final json = quoteJson(
      lines: [
        {
          'product_id': 'new-dish',
          'name': 'Új étel',
          'quantity': 1,
          'unit_price_huf': 1000,
          'vat_rate_percent': 27,
          'line_total_huf': 1000,
        },
      ],
    );

    expect(
      () => cartQuoteFromJson(json, menu),
      throwsA(
        isA<UnknownProductException>().having(
          (e) => e.productId,
          'productId',
          'new-dish',
        ),
      ),
    );
  });
}
