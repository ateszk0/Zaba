import '../domain/order_status.dart';

/// The database's word for each order status. The one place that knows them, for
/// the customer's orders and for the admin page alike.
const _codes = {
  OrderStatus.pendingPayment: 'pending_payment',
  OrderStatus.received: 'received',
  OrderStatus.preparing: 'preparing',
  OrderStatus.outForDelivery: 'out_for_delivery',
  OrderStatus.delivered: 'delivered',
  OrderStatus.cancelled: 'cancelled',
};

String orderStatusCode(OrderStatus status) => _codes[status]!;

/// Null for a word this app does not know: the caller decides whether that is
/// an error (showing a wrong status for a paid order would be worse).
OrderStatus? orderStatusFromCode(Object? code) {
  for (final MapEntry(key: status, value: word) in _codes.entries) {
    if (word == code) {
      return status;
    }
  }
  return null;
}
