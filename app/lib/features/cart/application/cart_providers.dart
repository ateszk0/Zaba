import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/application/catalog_providers.dart';
import '../../delivery/application/delivery_providers.dart';
import '../data/in_memory_quote_service.dart';
import '../domain/cart_quote.dart';
import '../domain/quote_service.dart';

final quoteServiceProvider = Provider<QuoteService>(
  (ref) => InMemoryQuoteService(
    catalog: ref.watch(catalogRepositoryProvider),
    zones: ref.watch(deliveryZoneRepositoryProvider),
  ),
);

/// The cart contents: product id to quantity. Holds no prices; they come from
/// the quote service.
class CartNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => const {};

  void add(String productId, {int quantity = 1}) {
    if (quantity <= 0) return;
    state = {...state, productId: (state[productId] ?? 0) + quantity};
  }

  void increment(String productId) => add(productId);

  /// Removes the line when the quantity reaches zero.
  void decrement(String productId) {
    final current = state[productId];
    if (current == null) return;
    if (current <= 1) {
      remove(productId);
    } else {
      state = {...state, productId: current - 1};
    }
  }

  void remove(String productId) {
    state = {
      for (final entry in state.entries)
        if (entry.key != productId) entry.key: entry.value,
    };
  }

  void clear() => state = const {};
}

final cartProvider = NotifierProvider<CartNotifier, Map<String, int>>(
  CartNotifier.new,
);

final cartItemCountProvider = Provider<int>(
  (ref) => ref
      .watch(cartProvider)
      .values
      .fold(0, (count, quantity) => count + quantity),
);

final cartQuoteProvider = FutureProvider<CartQuote>((ref) {
  final lines = ref.watch(cartProvider);
  final address = ref.watch(deliveryAddressProvider);
  return ref
      .watch(quoteServiceProvider)
      .quote(lines: lines, postalCode: address?.postalCode);
});
