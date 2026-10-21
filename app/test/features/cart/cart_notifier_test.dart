import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/features/cart/application/cart_providers.dart';

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
}
