import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/application/catalog_providers.dart';
import '../../delivery/application/delivery_providers.dart';
import '../data/in_memory_quote_service.dart';
import '../domain/cart_limits.dart';
import '../domain/cart_quote.dart';
import '../domain/cart_store.dart';
import '../domain/quote_service.dart';

final quoteServiceProvider = Provider<QuoteService>(
  (ref) => InMemoryQuoteService(
    catalog: ref.watch(catalogRepositoryProvider),
    zones: ref.watch(deliveryZoneRepositoryProvider),
  ),
);

/// Where the cart survives a reload. Nothing by default; `main.dart` swaps in
/// the browser's / the device's preferences.
final cartStoreProvider = Provider<CartStore>((ref) => MemoryCartStore());

/// The cart contents: product id to quantity. Holds no prices; they come from
/// the quote service. Every change is saved, so a reload keeps the cart.
class CartNotifier extends Notifier<Map<String, int>> {
  CartStore get _store => ref.read(cartStoreProvider);

  @override
  Map<String, int> build() => _store.load();

  void _update(Map<String, int> lines) {
    state = lines;
    _store.save(lines);
  }

  void add(String productId, {int quantity = 1}) {
    if (quantity <= 0) return;
    final total = (state[productId] ?? 0) + quantity;
    _update({
      ...state,
      productId: total > maxLineQuantity ? maxLineQuantity : total,
    });
  }

  void increment(String productId) => add(productId);

  /// Removes the line when the quantity reaches zero.
  void decrement(String productId) {
    final current = state[productId];
    if (current == null) return;
    if (current <= 1) {
      remove(productId);
    } else {
      _update({...state, productId: current - 1});
    }
  }

  void remove(String productId) {
    _update({
      for (final entry in state.entries)
        if (entry.key != productId) entry.key: entry.value,
    });
  }

  /// Drops the lines of products that are not in [productIds].
  void retainOnly(Set<String> productIds) {
    if (state.keys.every(productIds.contains)) return;
    _update({
      for (final entry in state.entries)
        if (productIds.contains(entry.key)) entry.key: entry.value,
    });
  }

  void clear() => _update(const {});
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

/// Loads the prices and the menu again after a failure.
void reloadCartQuote(WidgetRef ref) {
  ref.invalidate(productsProvider);
  ref.invalidate(cartQuoteProvider);
}

/// A cart that was saved earlier may hold a product that is no longer sold.
/// The server leaves such lines out of the quote; this takes them out of the
/// cart too, so the item count and the lines agree. Watched once, at the root
/// of the app. With an empty cart it asks the server nothing.
final cartPruningProvider = Provider<void>((ref) {
  if (ref.watch(cartItemCountProvider) == 0) return;
  ref.listen(cartQuoteProvider, (_, quote) {
    if (quote case AsyncData(:final value)) {
      ref.read(cartProvider.notifier).retainOnly({
        for (final line in value.lines) line.product.id,
      });
    }
  }, fireImmediately: true);
});
