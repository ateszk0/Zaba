import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/features/cart/application/cart_providers.dart';
import 'package:zaba/features/cart/domain/cart_limits.dart';
import 'package:zaba/features/cart/domain/cart_store.dart';

void main() {
  late ProviderContainer container;
  CartNotifier cart() => container.read(cartProvider.notifier);
  Map<String, int> lines() => container.read(cartProvider);

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('starts empty', () {
    expect(lines(), isEmpty);
    expect(container.read(cartItemCountProvider), 0);
  });

  test('add accumulates quantities per product', () {
    cart().add('carbonara');
    cart().add('carbonara', quantity: 2);
    cart().add('lemonade');

    expect(lines(), {'carbonara': 3, 'lemonade': 1});
    expect(container.read(cartItemCountProvider), 4);
  });

  test('add ignores non-positive quantities', () {
    cart().add('carbonara', quantity: 0);
    cart().add('carbonara', quantity: -2);

    expect(lines(), isEmpty);
  });

  test('decrement lowers the quantity and removes the line at zero', () {
    cart().add('carbonara', quantity: 2);

    cart().decrement('carbonara');
    expect(lines(), {'carbonara': 1});

    cart().decrement('carbonara');
    expect(lines(), isEmpty);
  });

  test('decrement of a product that is not in the cart does nothing', () {
    cart().decrement('ghost');

    expect(lines(), isEmpty);
  });

  test('remove drops a whole line and clear empties the cart', () {
    cart().add('carbonara', quantity: 3);
    cart().add('lemonade');

    cart().remove('carbonara');
    expect(lines(), {'lemonade': 1});

    cart().clear();
    expect(lines(), isEmpty);
  });

  test('never mutates a previously published state', () {
    cart().add('carbonara');
    final before = lines();

    cart().add('lemonade');

    expect(before, {'carbonara': 1});
  });

  test('a line never grows past what the server accepts', () {
    cart().add('carbonara', quantity: 98);
    cart().add('carbonara', quantity: 5);
    expect(lines(), {'carbonara': maxLineQuantity});

    cart().increment('carbonara');
    expect(lines(), {'carbonara': maxLineQuantity});
  });

  group('persistence', () {
    test('every change is saved, and a new session starts from the save', () {
      final store = MemoryCartStore();
      final first = ProviderContainer(
        overrides: [cartStoreProvider.overrideWithValue(store)],
      );
      first.read(cartProvider.notifier)
        ..add('carbonara', quantity: 2)
        ..add('lemonade')
        ..decrement('lemonade')
        ..add('arrabbiata');
      expect(store.load(), {'carbonara': 2, 'arrabbiata': 1});
      first.dispose();

      final second = ProviderContainer(
        overrides: [cartStoreProvider.overrideWithValue(store)],
      );
      addTearDown(second.dispose);
      expect(second.read(cartProvider), {'carbonara': 2, 'arrabbiata': 1});

      second.read(cartProvider.notifier).clear();
      expect(store.load(), isEmpty);
    });

    test(
      'retainOnly drops lines of products that are gone, and saves that',
      () {
        final store = MemoryCartStore({'carbonara': 2, 'ghost': 1});
        container = ProviderContainer(
          overrides: [cartStoreProvider.overrideWithValue(store)],
        );

        cart().retainOnly({'carbonara', 'lemonade'});

        expect(lines(), {'carbonara': 2});
        expect(store.load(), {'carbonara': 2});
      },
    );
  });
}
