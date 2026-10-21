import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock.dart';
import '../../../core/config/app_config.dart';
import '../../auth/application/auth_providers.dart';
import '../../cart/application/cart_providers.dart';
import '../../delivery/application/delivery_providers.dart';
import '../../payment/domain/payment_event.dart';
import '../data/in_memory_order_store.dart';
import '../domain/order.dart';
import '../domain/order_repository.dart';

/// One store plays the server for the demo: it serves the customer app, the
/// operator actions and the payment events.
final orderStoreProvider = Provider<InMemoryOrderStore>(
  (ref) => InMemoryOrderStore(
    quoteService: ref.watch(quoteServiceProvider),
    slotService: ref.watch(deliverySlotServiceProvider),
    clock: ref.watch(clockProvider),
  ),
);

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => ref.watch(orderStoreProvider),
);

final orderAdminProvider = Provider<OrderAdmin>(
  (ref) => ref.watch(orderStoreProvider),
);

final paymentEventSinkProvider = Provider<PaymentEventSink>(
  (ref) => ref.watch(orderStoreProvider),
);

/// Whether the order screen offers the "advance the order" button that stands in
/// for the kitchen. Only the offline demo has it: with a backend the kitchen is
/// the admin page.
final kitchenSimulationProvider = Provider<bool>(
  (ref) => AppConfig.showDevTools,
);

/// The customer's orders, newest first. Depends on who is signed in, so a
/// different customer on the same device never sees the previous one's orders,
/// and a guest asks the server nothing.
final ordersProvider = StreamProvider<List<Order>>((ref) {
  if (ref.watch(sessionProvider) == null) {
    return Stream.value(const <Order>[]);
  }
  return ref.watch(orderRepositoryProvider).watchOrders();
});

final orderProvider = StreamProvider.family<Order?, String>((ref, id) {
  if (ref.watch(sessionProvider) == null) {
    return Stream.value(null);
  }
  return ref.watch(orderRepositoryProvider).watchOrder(id);
});
