import '../../delivery/domain/delivery_address.dart';
import '../../delivery/domain/delivery_slot.dart';
import 'order.dart';
import 'order_status.dart';

class PlaceOrderRequest {
  const PlaceOrderRequest({
    required this.idempotencyKey,
    required this.lines,
    required this.address,
    required this.slot,
    this.note = '',
  });

  /// Chosen once per checkout attempt. Sending the same request again (double
  /// tap, retry after a lost response) returns the same order instead of
  /// creating a second one.
  final String idempotencyKey;

  /// Product id to quantity.
  final Map<String, int> lines;
  final DeliveryAddress address;
  final DeliverySlot slot;
  final String note;
}

/// How many orders one customer may have waiting for payment. A place in a delivery
/// slot is taken when the order is placed, before it is paid, so the number is
/// limited (the database enforces the same limit, and cancels orders that stay
/// unpaid for too long).
const maxUnpaidOrders = 5;

enum OrderRejection {
  emptyCart,
  outOfDeliveryArea,
  belowMinimumOrder,
  slotUnavailable,

  /// The customer already has [maxUnpaidOrders] orders waiting for payment.
  tooManyUnpaidOrders,
}

class OrderRejectedException implements Exception {
  const OrderRejectedException(this.reason);

  final OrderRejection reason;

  @override
  String toString() => 'OrderRejectedException: $reason';
}

class OrderNotCancellableException implements Exception {
  const OrderNotCancellableException(this.status);

  final OrderStatus status;

  @override
  String toString() => 'OrderNotCancellableException: $status';
}

class InvalidOrderTransitionException implements Exception {
  const InvalidOrderTransitionException(this.from, this.to);

  final OrderStatus from;
  final OrderStatus to;

  @override
  String toString() => 'InvalidOrderTransitionException: $from -> $to';
}

/// What the customer app can do with orders.
abstract interface class OrderRepository {
  /// Prices the cart again, validates area, minimum order and slot, and
  /// creates an order that is waiting for payment.
  ///
  /// Throws [OrderRejectedException].
  Future<Order> placeOrder(PlaceOrderRequest request);

  Future<Order?> findOrder(String id);

  /// The customer's orders, newest first; emits again on every change.
  Stream<List<Order>> watchOrders();

  Stream<Order?> watchOrder(String id);

  /// Throws [OrderNotCancellableException] once the kitchen has started.
  Future<void> cancelOrder(String id);
}

/// What the operator can do. On the real backend this is the admin API.
abstract interface class OrderAdmin {
  /// Throws [InvalidOrderTransitionException] for a move the state machine
  /// does not allow. An order cannot be marked as received by hand: only a
  /// payment event does that.
  Future<void> setStatus(String id, OrderStatus status);
}
