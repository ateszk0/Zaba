import 'cart_quote.dart';

class OutOfDeliveryAreaException implements Exception {
  const OutOfDeliveryAreaException(this.postalCode);

  final String postalCode;

  @override
  String toString() => 'OutOfDeliveryAreaException: $postalCode';
}

abstract interface class QuoteService {
  /// Prices [lines] (product id to quantity). Without a [postalCode] the
  /// default delivery zone is assumed and the quote is marked as estimated.
  ///
  /// Throws [OutOfDeliveryAreaException] if [postalCode] is not served.
  Future<CartQuote> quote({
    required Map<String, int> lines,
    String? postalCode,
  });
}
