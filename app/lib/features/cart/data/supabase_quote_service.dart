import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/money/money.dart';
import '../../catalog/domain/product.dart';
import '../domain/cart_quote.dart';
import '../domain/quote_service.dart';

/// Prices the cart on the server (`quote_cart`). The prices, the delivery fee
/// and the minimum order all come from there: the app only displays them.
class SupabaseQuoteService implements QuoteService {
  SupabaseQuoteService(this._client, {required this.loadProducts});

  final SupabaseClient _client;

  /// The menu, to show a photo and the allergens next to each priced line.
  final Future<List<Product>> Function() loadProducts;

  @override
  Future<CartQuote> quote({
    required Map<String, int> lines,
    String? postalCode,
  }) async {
    final products = {
      for (final product in await loadProducts()) product.id: product,
    };
    final Object? response;
    try {
      response = await _client.rpc(
        'quote_cart',
        params: {
          'p_lines': [
            for (final MapEntry(key: id, value: quantity) in lines.entries)
              if (quantity > 0) {'product_id': id, 'quantity': quantity},
          ],
          'p_postal_code': postalCode,
        },
      );
    } on PostgrestException catch (error) {
      // The server's errors are short codes.
      if (error.message == 'out_of_delivery_area') {
        throw OutOfDeliveryAreaException(postalCode ?? '');
      }
      rethrow;
    }
    return cartQuoteFromJson(response! as Map<String, dynamic>, products);
  }
}

/// Throws [UnknownProductException] for a line whose product is not in
/// [products].
CartQuote cartQuoteFromJson(
  Map<String, dynamic> json,
  Map<String, Product> products,
) {
  final lines = [
    for (final line in json['lines'] as List<dynamic>)
      _lineFromJson(line as Map<String, dynamic>, products),
  ];
  final freeFrom = json['free_delivery_from_huf'] as int?;
  return CartQuote(
    lines: lines,
    subtotal: Money(json['subtotal_huf'] as int),
    deliveryFee: Money(json['delivery_fee_huf'] as int),
    minOrder: Money(json['min_order_huf'] as int),
    freeDeliveryFrom: freeFrom == null ? null : Money(freeFrom),
    estimated: json['estimated'] as bool,
  );
}

QuoteLine _lineFromJson(
  Map<String, dynamic> line,
  Map<String, Product> products,
) {
  final id = line['product_id'] as String;
  final product = products[id];
  if (product == null) {
    throw UnknownProductException(id);
  }
  return QuoteLine(
    product: product,
    quantity: line['quantity'] as int,
    unitPrice: Money(line['unit_price_huf'] as int),
    total: Money(line['line_total_huf'] as int),
  );
}
