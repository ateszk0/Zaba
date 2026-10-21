import 'dart:async';

import '../../../core/clock/clock.dart';
import '../../cart/domain/cart_quote.dart';
import '../../cart/domain/quote_service.dart';
import '../../delivery/domain/delivery_slot_service.dart';
import '../../payment/domain/payment_event.dart';
import '../domain/order.dart';
import '../domain/order_repository.dart';
import '../domain/order_status.dart';

/// Moves an operator may make. Mirrors the server's transition table; the
/// move to `received` is deliberately missing, only a payment event does it.
const _operatorTransitions = <OrderStatus, Set<OrderStatus>>{
  OrderStatus.pendingPayment: {OrderStatus.cancelled},
  OrderStatus.received: {OrderStatus.preparing, OrderStatus.cancelled},
  OrderStatus.preparing: {OrderStatus.outForDelivery, OrderStatus.cancelled},
  OrderStatus.outForDelivery: {OrderStatus.delivered},
  OrderStatus.delivered: <OrderStatus>{},
  OrderStatus.cancelled: <OrderStatus>{},
};

/// Plays the server for the demo: validates and stores orders, applies payment
/// events once, and enforces the order state machine. Replaced by the Supabase
/// backed implementation; stays useful as a test double.
class InMemoryOrderStore
    implements OrderRepository, OrderAdmin, PaymentEventSink {
  InMemoryOrderStore({
    required this.quoteService,
    required this.slotService,
    required this.clock,
  });

  final QuoteService quoteService;
  final DeliverySlotService slotService;
  final Clock clock;

  final _orders = <String, Order>{};
  final _idByKey = <String, String>{};
  final _seenEvents = <String>{};
  final _changes = StreamController<void>.broadcast(sync: true);
  var _counter = 1000;

  List<Order> _snapshot() =>
      List.unmodifiable(_orders.values.toList().reversed);

  void _put(Order order) {
    _orders[order.id] = order;
    _changes.add(null);
  }

  @override
  Future<Order> placeOrder(PlaceOrderRequest request) async {
    final replay = _idByKey[request.idempotencyKey];
    if (replay != null) return _orders[replay]!;

    final unpaid = _orders.values
        .where((order) => order.status == OrderStatus.pendingPayment)
        .length;
    if (unpaid >= maxUnpaidOrders) {
      throw const OrderRejectedException(OrderRejection.tooManyUnpaidOrders);
    }

    final lines = {
      for (final entry in request.lines.entries)
        if (entry.value > 0) entry.key: entry.value,
    };
    if (lines.isEmpty) {
      throw const OrderRejectedException(OrderRejection.emptyCart);
    }

    final CartQuote quote;
    try {
      quote = await quoteService.quote(
        lines: lines,
        postalCode: request.address.postalCode,
      );
    } on OutOfDeliveryAreaException {
      throw const OrderRejectedException(OrderRejection.outOfDeliveryArea);
    }
    if (quote.isEmpty) {
      throw const OrderRejectedException(OrderRejection.emptyCart);
    }
    if (!quote.meetsMinOrder) {
      throw const OrderRejectedException(OrderRejection.belowMinimumOrder);
    }
    if (!await slotService.isAvailable(request.slot, now: clock())) {
      throw const OrderRejectedException(OrderRejection.slotUnavailable);
    }

    // A second call with the same key may have finished while this one was
    // waiting on the checks above (double tap).
    final raced = _idByKey[request.idempotencyKey];
    if (raced != null) return _orders[raced]!;

    _counter++;
    final order = Order(
      id: 'o-$_counter',
      number: 'ZB-$_counter',
      placedAt: clock(),
      lines: [
        for (final line in quote.lines)
          OrderLine(
            productId: line.product.id,
            name: line.product.name,
            quantity: line.quantity,
            unitPrice: line.product.price,
          ),
      ],
      subtotal: quote.subtotal,
      deliveryFee: quote.deliveryFee,
      address: request.address,
      slot: request.slot,
      note: request.note.trim(),
      status: OrderStatus.pendingPayment,
      paymentStatus: PaymentStatus.pending,
    );
    _idByKey[request.idempotencyKey] = order.id;
    _put(order);
    return order;
  }

  @override
  Future<Order?> findOrder(String id) async => _orders[id];

  @override
  Stream<List<Order>> watchOrders() => Stream.multi((controller) {
    controller.add(_snapshot());
    final subscription = _changes.stream.listen(
      (_) => controller.add(_snapshot()),
    );
    controller.onCancel = subscription.cancel;
  });

  @override
  Stream<Order?> watchOrder(String id) => Stream.multi((controller) {
    controller.add(_orders[id]);
    final subscription = _changes.stream.listen(
      (_) => controller.add(_orders[id]),
    );
    controller.onCancel = subscription.cancel;
  });

  @override
  Future<void> cancelOrder(String id) async {
    final order = _orders[id];
    if (order == null) return;
    if (!order.status.customerCanCancel) {
      throw OrderNotCancellableException(order.status);
    }
    _cancel(order);
  }

  void _cancel(Order order) {
    // A paid order is refunded in full; in the demo that is immediate.
    _put(
      order.copyWith(
        status: OrderStatus.cancelled,
        paymentStatus: order.paymentStatus == PaymentStatus.succeeded
            ? PaymentStatus.refunded
            : order.paymentStatus,
      ),
    );
  }

  @override
  Future<void> setStatus(String id, OrderStatus status) async {
    final order = _orders[id];
    if (order == null) return;
    if (!(_operatorTransitions[order.status]?.contains(status) ?? false)) {
      throw InvalidOrderTransitionException(order.status, status);
    }
    if (status == OrderStatus.cancelled) {
      _cancel(order);
    } else {
      _put(order.copyWith(status: status));
    }
  }

  @override
  Future<void> apply(PaymentEvent event) async {
    if (!_seenEvents.add(event.id)) return;
    final order = _orders[event.orderId];
    // Events only matter while the order waits for payment. A success that
    // arrives for an already cancelled order would need a refund; that case
    // comes with the real payment provider.
    if (order == null || order.status != OrderStatus.pendingPayment) return;

    switch (event.type) {
      case PaymentEventType.succeeded:
        _put(
          order.copyWith(
            status: OrderStatus.received,
            paymentStatus: PaymentStatus.succeeded,
          ),
        );
      case PaymentEventType.failed:
        _put(order.copyWith(paymentStatus: PaymentStatus.failed));
      case PaymentEventType.cancelled:
        _put(order.copyWith(paymentStatus: PaymentStatus.cancelled));
    }
  }
}
