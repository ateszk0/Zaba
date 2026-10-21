import 'cart_quote.dart';

class OutOfDeliveryAreaException implements Exception {
  const OutOfDeliveryAreaException(this.postalCode);

  final String postalCode;

  @override
  String toString() => 'OutOfDeliveryAreaException: $postalCode';
}

/// The server priced a product the app does not know (the menu on the device is
/// older than the server's). Reloading the menu fixes it.
class UnknownProductException implements Exception {
  const UnknownProductException(this.productId);

  final String productId;

  @override
  String toString() => 'UnknownProductException: $productId';
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
