import '../../../core/money/money.dart';
import '../../catalog/domain/catalog_repository.dart';
import '../../delivery/domain/delivery_zone_repository.dart';
import '../domain/cart_quote.dart';
import '../domain/quote_service.dart';

/// Mirrors what the server-side pricing function will do. Replaced by the
/// Supabase RPC; stays useful as a test double.
class InMemoryQuoteService implements QuoteService {
  const InMemoryQuoteService({required this.catalog, required this.zones});

  final CatalogRepository catalog;
  final DeliveryZoneRepository zones;

  @override
  Future<CartQuote> quote({
    required Map<String, int> lines,
    String? postalCode,
  }) async {
    final zone = postalCode == null
        ? await zones.defaultZone()
        : await zones.zoneForPostalCode(postalCode);
    if (zone == null) throw OutOfDeliveryAreaException(postalCode!);

    final products = {
      for (final product in await catalog.products()) product.id: product,
    };
    final quoteLines = [
      for (final MapEntry(key: id, value: quantity) in lines.entries)
        if (quantity > 0 && products[id] != null)
          QuoteLine(product: products[id]!, quantity: quantity),
    ];

    final subtotal = Money.sum(quoteLines.map((line) => line.total));
    final freeFrom = zone.freeDeliveryFrom;
    final isFree =
        quoteLines.isEmpty || (freeFrom != null && subtotal >= freeFrom);

    return CartQuote(
      lines: quoteLines,
      subtotal: subtotal,
      deliveryFee: isFree ? Money.zero : zone.deliveryFee,
      minOrder: zone.minOrder,
      freeDeliveryFrom: freeFrom,
      estimated: postalCode == null,
    );
  }
}
