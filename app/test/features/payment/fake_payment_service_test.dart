import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/features/orders/domain/order.dart';
import 'package:zaba/features/orders/domain/order_status.dart';
import 'package:zaba/features/payment/data/fake_payment_service.dart';
import 'package:zaba/features/payment/domain/card_outcome.dart';

import '../../support/order_fixtures.dart';

void main() {
  test('an approved card pays the order through a payment event', () async {
    final store = newOrderStore();
    final order = await store.placeOrder(validRequest());
    final service = FakePaymentService(
      sink: store,
      orders: store,
      processingDelay: Duration.zero,
    );

    final status = await service.submit(
      orderId: order.id,
      outcome: CardOutcome.approved,
    );

    expect(status, PaymentStatus.succeeded);
    expect((await store.findOrder(order.id))!.status, OrderStatus.received);
  });

  test('a declined card leaves the order waiting for payment', () async {
    final store = newOrderStore();
    final order = await store.placeOrder(validRequest());
    final service = FakePaymentService(
      sink: store,
      orders: store,
      processingDelay: Duration.zero,
    );

    final status = await service.submit(
      orderId: order.id,
      outcome: CardOutcome.declined,
    );

    expect(status, PaymentStatus.failed);
    expect(
      (await store.findOrder(order.id))!.status,
      OrderStatus.pendingPayment,
    );
  });

  test('a cancelled card step is reported as a cancelled payment', () async {
    final store = newOrderStore();
    final order = await store.placeOrder(validRequest());
    final service = FakePaymentService(
      sink: store,
      orders: store,
      processingDelay: Duration.zero,
    );

    final status = await service.submit(
      orderId: order.id,
      outcome: CardOutcome.cancelled,
    );

    expect(status, PaymentStatus.cancelled);
    expect(
      (await store.findOrder(order.id))!.status,
      OrderStatus.pendingPayment,
    );
  });

  test(
    'retrying after a decline can still succeed (each attempt is a new event)',
    () async {
      final store = newOrderStore();
      final order = await store.placeOrder(validRequest());
      final service = FakePaymentService(
        sink: store,
        orders: store,
        processingDelay: Duration.zero,
      );

      await service.submit(orderId: order.id, outcome: CardOutcome.declined);
      final status = await service.submit(
        orderId: order.id,
        outcome: CardOutcome.approved,
      );

      expect(status, PaymentStatus.succeeded);
    },
  );
}
