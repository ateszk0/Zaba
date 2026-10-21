import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/core/money/money.dart';
import 'package:zaba/features/orders/data/supabase_order_repository.dart';
import 'package:zaba/features/orders/domain/order.dart';
import 'package:zaba/features/orders/domain/order_status.dart';

/// The shape the `orders` query answers with.
Map<String, dynamic> orderRow({
  String status = 'received',
  String paymentStatus = 'succeeded',
  Object? slot = const {
    'id': '33333333-3333-4333-8333-333333333333',
    'starts_at': '2026-10-21T10:00:00+00:00',
    'ends_at': '2026-10-21T11:00:00+00:00',
  },
  List<Map<String, dynamic>>? items,
}) => {
  'id': '11111111-1111-4111-8111-111111111111',
  'number': 'ZB-1001',
  'created_at': '2026-10-21T08:30:00.123456+00:00',
  'status': status,
  'payment_status': paymentStatus,
  'subtotal_huf': 5580,
  'delivery_fee_huf': 990,
  'delivery_postal_code': '1051',
  'delivery_street': 'Váci utca 12.',
  'note': 'Csengess kétszer.',
  'slot': slot,
  'order_items':
      items ??
      [
        {
          'id': 8,
          'product_id': 'lemonade',
          'name': 'Házi limonádé',
          'quantity': 1,
          'unit_price_huf': 790,
        },
        {
          'id': 7,
          'product_id': 'carbonara',
          'name': 'Spagetti carbonara',
          'quantity': 2,
          'unit_price_huf': 2790,
        },
      ],
};

void main() {
  test('an order row becomes an order with everything the screens show', () {
    final order = orderFromRow(orderRow());

    expect(order.id, '11111111-1111-4111-8111-111111111111');
    expect(order.number, 'ZB-1001');
    expect(
      order.placedAt.isAtSameMomentAs(
        DateTime.utc(2026, 10, 21, 8, 30, 0, 123, 456),
      ),
      isTrue,
    );
    expect(order.status, OrderStatus.received);
    expect(order.paymentStatus, PaymentStatus.succeeded);
    expect(order.subtotal, const Money(5580));
    expect(order.deliveryFee, const Money(990));
    expect(order.total, const Money(6570));
    expect(order.address.postalCode, '1051');
    expect(order.address.street, 'Váci utca 12.');
    expect(order.note, 'Csengess kétszer.');
    expect(order.slot.id, '33333333-3333-4333-8333-333333333333');
    expect(order.slot.end.difference(order.slot.start).inMinutes, 60);
  });

  test(
    'the lines come in the order they were placed, whatever the server sends',
    () {
      final order = orderFromRow(orderRow());

      expect(order.lines.map((l) => l.productId), ['carbonara', 'lemonade']);
      expect(order.lines.first.total, const Money(5580));
      expect(order.itemCount, 3);
    },
  );

  test('every status the database knows maps to one of the app', () {
    const statuses = {
      'pending_payment': OrderStatus.pendingPayment,
      'received': OrderStatus.received,
      'preparing': OrderStatus.preparing,
      'out_for_delivery': OrderStatus.outForDelivery,
      'delivered': OrderStatus.delivered,
      'cancelled': OrderStatus.cancelled,
    };
    for (final MapEntry(key: text, value: status) in statuses.entries) {
      expect(orderFromRow(orderRow(status: text)).status, status, reason: text);
    }
    const payments = {
      'pending': PaymentStatus.pending,
      'succeeded': PaymentStatus.succeeded,
      'failed': PaymentStatus.failed,
      'cancelled': PaymentStatus.cancelled,
      'refunded': PaymentStatus.refunded,
    };
    for (final MapEntry(key: text, value: status) in payments.entries) {
      expect(
        orderFromRow(orderRow(paymentStatus: text)).paymentStatus,
        status,
        reason: text,
      );
    }
  });

  test('an unknown status or a missing slot is an error, never a guess', () {
    expect(
      () => orderFromRow(orderRow(status: 'teleported')),
      throwsFormatException,
    );
    expect(
      () => orderFromRow(orderRow(paymentStatus: 'maybe')),
      throwsFormatException,
    );
    expect(() => orderFromRow(orderRow(slot: null)), throwsFormatException);
  });
}
