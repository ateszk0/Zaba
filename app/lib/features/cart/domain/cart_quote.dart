import '../../../core/money/money.dart';
import '../../catalog/domain/product.dart';

class QuoteLine {
  const QuoteLine({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  Money get total => product.price * quantity;
}

/// The priced cart. It is produced by a [QuoteService] (on the real backend:
/// the server); the client only displays it and never computes its own total.
class CartQuote {
  const CartQuote({
    required this.lines,
    required this.subtotal,
    required this.deliveryFee,
    required this.minOrder,
    required this.estimated,
    this.freeDeliveryFrom,
  });

  final List<QuoteLine> lines;
  final Money subtotal;
  final Money deliveryFee;
  final Money minOrder;
  final Money? freeDeliveryFrom;

  /// True while no delivery address is known, so the delivery terms are those
  /// of the default zone and may change.
  final bool estimated;

  Money get total => subtotal + deliveryFee;

  bool get isEmpty => lines.isEmpty;

  int get itemCount => lines.fold(0, (count, line) => count + line.quantity);

  /// How much is still missing to reach the minimum order value (zero if met).
  Money get minOrderShortfall =>
      subtotal < minOrder ? minOrder - subtotal : Money.zero;

  bool get meetsMinOrder => minOrderShortfall == Money.zero;

  /// How much more to order for free delivery; null if delivery is already
  /// free or never is.
  Money? get remainingForFreeDelivery {
    final threshold = freeDeliveryFrom;
    if (threshold == null || subtotal >= threshold) return null;
    return threshold - subtotal;
  }
}
