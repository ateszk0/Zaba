import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock.dart';
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

/// The customer's orders, newest first.
final ordersProvider = StreamProvider<List<Order>>(
  (ref) => ref.watch(orderRepositoryProvider).watchOrders(),
);

final orderProvider = StreamProvider.family<Order?, String>(
  (ref, id) => ref.watch(orderRepositoryProvider).watchOrder(id),
);
