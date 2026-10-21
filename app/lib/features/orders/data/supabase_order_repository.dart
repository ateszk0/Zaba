import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/money/money.dart';
import '../../../core/realtime/live_query.dart';
import '../../delivery/domain/delivery_address.dart';
import '../../delivery/domain/delivery_slot.dart';
import '../domain/order.dart';
import '../domain/order_repository.dart';
import '../domain/order_status.dart';

/// The customer's orders on Supabase. Orders are only ever created and changed
/// by database functions (`place_order`, `cancel_order`) and by the payment
/// webhook; the app reads them (row level security shows a customer their own)
/// and follows them live.
class SupabaseOrderRepository implements OrderRepository {
  SupabaseOrderRepository(this._client);

  final SupabaseClient _client;

  /// The order with its lines and its delivery window.
  static const _columns =
      'id, number, created_at, status, payment_status, subtotal_huf, '
      'delivery_fee_huf, delivery_postal_code, delivery_street, note, '
      'slot:delivery_slots(id, starts_at, ends_at), '
      'order_items(id, product_id, name, quantity, unit_price_huf)';

  @override
  Future<Order> placeOrder(PlaceOrderRequest request) async {
    final Object? placed;
    try {
      placed = await _client.rpc(
        'place_order',
        params: {
          'p_idempotency_key': request.idempotencyKey,
          'p_lines': [
            for (final MapEntry(key: id, value: quantity)
                in request.lines.entries)
              if (quantity > 0) {'product_id': id, 'quantity': quantity},
          ],
          'p_postal_code': request.address.postalCode,
          'p_street': request.address.street,
          'p_slot_id': request.slot.id,
          'p_note': request.note,
        },
      );
    } on PostgrestException catch (error) {
      final rejection = _rejections[error.message];
      if (rejection != null) {
        throw OrderRejectedException(rejection);
      }
      rethrow;
    }
    final id = (placed! as Map<String, dynamic>)['id'] as String;
    final order = await findOrder(id);
    if (order == null) {
      throw StateError('The order $id was placed but cannot be read.');
    }
    return order;
  }

  static const _rejections = {
    'empty_cart': OrderRejection.emptyCart,
    'out_of_delivery_area': OrderRejection.outOfDeliveryArea,
    'below_minimum_order': OrderRejection.belowMinimumOrder,
    'slot_unavailable': OrderRejection.slotUnavailable,
  };

  @override
  Future<Order?> findOrder(String id) async {
    final row = await _client
        .from('orders')
        .select(_columns)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : orderFromRow(row);
  }

  @override
  Stream<List<Order>> watchOrders() => liveQuery(
    feed: realtimeChangeFeed(_client, table: 'orders'),
    fetch: () async {
      final rows = await _client
          .from('orders')
          .select(_columns)
          .order('created_at', ascending: false)
          .limit(50);
      return rows.map(orderFromRow).toList(growable: false);
    },
  );

  @override
  Stream<Order?> watchOrder(String id) => liveQuery(
    feed: realtimeChangeFeed(
      _client,
      table: 'orders',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: id,
      ),
    ),
    fetch: () => findOrder(id),
  );

  @override
  Future<void> cancelOrder(String id) async {
    try {
      await _client.rpc('cancel_order', params: {'p_order_id': id});
    } on PostgrestException catch (error) {
      if (error.message == 'invalid_transition') {
        final order = await findOrder(id);
        if (order != null) {
          throw OrderNotCancellableException(order.status);
        }
      }
      rethrow;
    }
  }
}

const _statuses = {
  'pending_payment': OrderStatus.pendingPayment,
  'received': OrderStatus.received,
  'preparing': OrderStatus.preparing,
  'out_for_delivery': OrderStatus.outForDelivery,
  'delivered': OrderStatus.delivered,
  'cancelled': OrderStatus.cancelled,
};

const _paymentStatuses = {
  'pending': PaymentStatus.pending,
  'succeeded': PaymentStatus.succeeded,
  'failed': PaymentStatus.failed,
  'cancelled': PaymentStatus.cancelled,
  'refunded': PaymentStatus.refunded,
};

/// Throws a [FormatException] for a status this app does not know, instead of
/// guessing: showing the wrong state of a paid order would be worse than an
/// error.
Order orderFromRow(Map<String, dynamic> row) {
  final slot = row['slot'] as Map<String, dynamic>?;
  if (slot == null) {
    throw FormatException('The order has no readable delivery slot', row['id']);
  }
  final items = [...(row['order_items'] as List<dynamic>)]
    ..sort(
      (a, b) => ((a as Map)['id'] as int).compareTo((b as Map)['id'] as int),
    );
  final status = _statuses[row['status']];
  final paymentStatus = _paymentStatuses[row['payment_status']];
  if (status == null || paymentStatus == null) {
    throw FormatException('Unknown order status', row['status']);
  }
  return Order(
    id: row['id'] as String,
    number: row['number'] as String,
    placedAt: DateTime.parse(row['created_at'] as String).toLocal(),
    lines: [
      for (final item in items.cast<Map<String, dynamic>>())
        OrderLine(
          productId: item['product_id'] as String,
          name: item['name'] as String,
          quantity: item['quantity'] as int,
          unitPrice: Money(item['unit_price_huf'] as int),
        ),
    ],
    subtotal: Money(row['subtotal_huf'] as int),
    deliveryFee: Money(row['delivery_fee_huf'] as int),
    address: DeliveryAddress(
      postalCode: row['delivery_postal_code'] as String,
      street: row['delivery_street'] as String,
    ),
    slot: DeliverySlot(
      id: slot['id'] as String,
      start: DateTime.parse(slot['starts_at'] as String).toLocal(),
      end: DateTime.parse(slot['ends_at'] as String).toLocal(),
    ),
    note: row['note'] as String,
    status: status,
    paymentStatus: paymentStatus,
  );
}
