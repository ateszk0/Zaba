import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/features/auth/application/auth_providers.dart';
import 'package:zaba/features/auth/data/in_memory_auth_repository.dart';
import 'package:zaba/features/orders/application/order_providers.dart';
import 'package:zaba/features/orders/domain/order.dart';
import 'package:zaba/features/orders/domain/order_repository.dart';

import '../../support/order_fixtures.dart';

/// Counts how often somebody asks it for orders.
class CountingOrders implements OrderRepository {
  CountingOrders(this.order);

  final Order order;
  var listCalls = 0;
  var singleCalls = 0;

  @override
  Stream<List<Order>> watchOrders() {
    listCalls++;
    return Stream.value([order]);
  }

  @override
  Stream<Order?> watchOrder(String id) {
    singleCalls++;
    return Stream.value(order);
  }

  @override
  Future<Order> placeOrder(PlaceOrderRequest request) =>
      throw UnimplementedError();

  @override
  Future<Order?> findOrder(String id) async => order;

  @override
  Future<void> cancelOrder(String id) async {}
}

void main() {
  late InMemoryAuthRepository auth;
  late CountingOrders orders;
  late ProviderContainer container;

  setUp(() {
    auth = InMemoryAuthRepository(accounts: [offlineDemoAccount]);
    orders = CountingOrders(sampleOrder());
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        orderRepositoryProvider.overrideWithValue(orders),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    auth.dispose();
  });

  test('a guest has no orders and the backend is not asked', () async {
    // A provider nobody listens to is paused, so listen like a screen does.
    final list = container.listen(ordersProvider, (_, _) {});
    final single = container.listen(orderProvider('any'), (_, _) {});
    addTearDown(list.close);
    addTearDown(single.close);

    expect(await container.read(ordersProvider.future), isEmpty);
    expect(await container.read(orderProvider('any').future), isNull);
    expect(orders.listCalls, 0);
    expect(orders.singleCalls, 0);
  });

  test(
    'signing in brings the orders, signing out takes them away again',
    () async {
      final subscription = container.listen(ordersProvider, (_, _) {});
      addTearDown(subscription.close);
      expect(await container.read(ordersProvider.future), isEmpty);

      await auth.signIn(
        email: offlineDemoAccount.email,
        password: offlineDemoAccount.password,
      );
      await Future<void>.delayed(Duration.zero);
      expect(await container.read(ordersProvider.future), hasLength(1));
      expect(orders.listCalls, 1);

      await auth.signOut();
      await Future<void>.delayed(Duration.zero);
      expect(await container.read(ordersProvider.future), isEmpty);
    },
  );
}
