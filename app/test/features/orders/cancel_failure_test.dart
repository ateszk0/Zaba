import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/features/orders/application/order_providers.dart';
import 'package:zaba/features/orders/domain/order.dart';
import 'package:zaba/features/orders/domain/order_repository.dart';
import 'package:zaba/features/orders/domain/order_status.dart';

import '../../support/checkout_steps.dart';

/// The demo store, except that cancelling fails with [failure]: the kitchen
/// started a moment ago (an [OrderNotCancellableException]), or the network is
/// gone.
class _CancelFails implements OrderRepository {
  _CancelFails(this._store, this.failure);

  final OrderRepository _store;
  final Object failure;

  @override
  Future<void> cancelOrder(String id) async => throw failure;

  @override
  Future<Order> placeOrder(PlaceOrderRequest request) =>
      _store.placeOrder(request);

  @override
  Future<Order?> findOrder(String id) => _store.findOrder(id);

  @override
  Stream<List<Order>> watchOrders() => _store.watchOrders();

  @override
  Stream<Order?> watchOrder(String id) => _store.watchOrder(id);
}

Future<void> cancelPaidOrder(WidgetTester tester, Object failure) async {
  await reachCheckout(
    tester,
    overrides: [
      orderRepositoryProvider.overrideWith(
        (ref) => _CancelFails(ref.watch(orderStoreProvider), failure),
      ),
    ],
  );
  await placeOrder(tester);
  await fillCard(tester);
  await pay(tester);

  await tester.tap(find.text('Rendelés lemondása'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Lemondom'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('when the kitchen has just started, the customer is told why '
      'the order stays', (tester) async {
    await cancelPaidOrder(
      tester,
      const OrderNotCancellableException(OrderStatus.preparing),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.text(
        'A rendelést már nem lehet lemondani: a konyha elkezdte készíteni.',
      ),
      findsOneWidget,
    );
    expect(find.text('Rendelés fogadva'), findsWidgets);
  });

  testWidgets('when cancelling fails for another reason, the customer is told '
      'to try again', (tester) async {
    await cancelPaidOrder(tester, StateError('offline'));

    expect(tester.takeException(), isNull);
    expect(
      find.text('A lemondás nem sikerült. Próbáld meg újra.'),
      findsOneWidget,
    );
    // The button is still there for the next try.
    expect(find.text('Rendelés lemondása'), findsOneWidget);
  });
}
