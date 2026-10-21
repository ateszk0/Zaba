import '../../orders/domain/order.dart';
import '../../orders/domain/order_status.dart';

/// A message to the customer about one of their orders.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.refunded,
    required this.createdAt,
  });

  final String id;
  final String orderId;
  final String orderNumber;

  /// The status the order just reached.
  final OrderStatus status;

  /// A paid order that was cancelled: the message mentions the refund.
  final bool refunded;
  final DateTime createdAt;
}

/// Delivers a notification. The demo only shows it inside the app (see
/// `InAppNotifier`); the MVP adds senders for push messages and email behind the
/// same interface.
abstract interface class NotificationSender {
  void send(AppNotification notification);
}

/// An order whose status is not what it was.
class OrderStatusChange {
  const OrderStatusChange({required this.order, required this.from});

  final Order order;
  final OrderStatus from;
}

/// The orders of [next] whose status differs from [previous]. Orders that
/// appear for the first time are not changes (a new order is the customer's own
/// doing), and without a [previous] list nothing is: the first load is not news.
List<OrderStatusChange> statusChanges(List<Order>? previous, List<Order> next) {
  if (previous == null) {
    return const [];
  }
  final before = {for (final order in previous) order.id: order.status};
  return [
    for (final order in next)
      if (before[order.id] case final from? when from != order.status)
        OrderStatusChange(order: order, from: from),
  ];
}
