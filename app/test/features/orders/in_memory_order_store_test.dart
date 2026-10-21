import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/core/money/money.dart';
import 'package:zaba/features/delivery/domain/delivery_slot.dart';
import 'package:zaba/features/orders/domain/order.dart';
import 'package:zaba/features/orders/domain/order_repository.dart';
import 'package:zaba/features/orders/domain/order_status.dart';
import 'package:zaba/features/payment/domain/payment_event.dart';

import '../../support/order_fixtures.dart';

PaymentEvent event(String id, String orderId, PaymentEventType type) =>
    PaymentEvent(id: id, orderId: orderId, type: type);

Matcher rejectedWith(OrderRejection reason) => throwsA(
  isA<OrderRejectedException>().having((e) => e.reason, 'reason', reason),
);

void main() {
  group('placing an order', () {
    test(
      'creates an order that waits for payment, priced by the quote service',
      () async {
        final store = newOrderStore();

        final order = await store.placeOrder(validRequest());

        expect(order.number, 'ZB-1001');
        expect(order.status, OrderStatus.pendingPayment);
        expect(order.paymentStatus, PaymentStatus.pending);
        expect(order.subtotal, const Money(5580));
        expect(order.deliveryFee, const Money(990));
        expect(order.total, const Money(6570));
        expect(order.itemCount, 2);
        expect(order.lines.single.name, 'Spagetti carbonara');
        expect(order.note, 'csengő nem működik');
        expect(order.placedAt, fixedNow);
      },
    );

    test('the same idempotency key returns the same order', () async {
      final store = newOrderStore();

      final first = await store.placeOrder(validRequest());
      final second = await store.placeOrder(validRequest());

      expect(second.id, first.id);
      expect((await store.watchOrders().first).length, 1);
    });

    test('two concurrent calls with the same key create one order', () async {
      final store = newOrderStore();

      final results = await Future.wait([
        store.placeOrder(validRequest()),
        store.placeOrder(validRequest()),
      ]);

      expect(results[0].id, results[1].id);
      expect((await store.watchOrders().first).length, 1);
    });

    test(
      'different keys create different orders with increasing numbers',
      () async {
        final store = newOrderStore();

        final first = await store.placeOrder(validRequest(key: 'a'));
        final second = await store.placeOrder(validRequest(key: 'b'));

        expect([first.number, second.number], ['ZB-1001', 'ZB-1002']);
      },
    );

    test('rejects an empty cart', () async {
      final store = newOrderStore();
      final request = PlaceOrderRequest(
        idempotencyKey: 'k',
        lines: const {'carbonara': 0},
        address: innerAddress,
        slot: bookableSlot,
      );

      await expectLater(
        store.placeOrder(request),
        rejectedWith(OrderRejection.emptyCart),
      );
    });

    test('rejects an address outside the delivery area', () async {
      final store = newOrderStore();
      final request = PlaceOrderRequest(
        idempotencyKey: 'k',
        lines: const {'carbonara': 2},
        address: outsideAddress,
        slot: bookableSlot,
      );

      await expectLater(
        store.placeOrder(request),
        rejectedWith(OrderRejection.outOfDeliveryArea),
      );
    });

    test('rejects an order below the minimum order value', () async {
      final store = newOrderStore();
      final request = PlaceOrderRequest(
        idempotencyKey: 'k',
        lines: const {'lemonade': 1},
        address: innerAddress,
        slot: bookableSlot,
      );

      await expectLater(
        store.placeOrder(request),
        rejectedWith(OrderRejection.belowMinimumOrder),
      );
    });

    test('rejects a slot that is no longer bookable', () async {
      final store = newOrderStore();
      final request = PlaceOrderRequest(
        idempotencyKey: 'k',
        lines: const {'carbonara': 2},
        address: innerAddress,
        slot: DeliverySlot(
          id: 'too-soon',
          start: DateTime(2026, 10, 21, 10),
          end: DateTime(2026, 10, 21, 11),
        ),
      );

      await expectLater(
        store.placeOrder(request),
        rejectedWith(OrderRejection.slotUnavailable),
      );
    });

    test('a rejected request leaves no order behind', () async {
      final store = newOrderStore();
      final request = PlaceOrderRequest(
        idempotencyKey: 'k',
        lines: const {'lemonade': 1},
        address: innerAddress,
        slot: bookableSlot,
      );

      await expectLater(
        store.placeOrder(request),
        throwsA(isA<OrderRejectedException>()),
      );

      expect(await store.watchOrders().first, isEmpty);
    });
  });

  group('payment events', () {
    test('a successful payment moves the order to received', () async {
      final store = newOrderStore();
      final order = await store.placeOrder(validRequest());

      await store.apply(event('e1', order.id, PaymentEventType.succeeded));

      final updated = (await store.findOrder(order.id))!;
      expect(updated.status, OrderStatus.received);
      expect(updated.paymentStatus, PaymentStatus.succeeded);
    });

    test('the same event delivered twice has an effect only once', () async {
      final store = newOrderStore();
      final order = await store.placeOrder(validRequest());
      await store.apply(event('e1', order.id, PaymentEventType.succeeded));
      await store.setStatus(order.id, OrderStatus.preparing);

      // Redelivery of the success event must not touch the order any more.
      await store.apply(event('e1', order.id, PaymentEventType.succeeded));

      expect((await store.findOrder(order.id))!.status, OrderStatus.preparing);
    });

    test('a declined payment keeps the order waiting and payable', () async {
      final store = newOrderStore();
      final order = await store.placeOrder(validRequest());

      await store.apply(event('e1', order.id, PaymentEventType.failed));
      var current = (await store.findOrder(order.id))!;
      expect(current.status, OrderStatus.pendingPayment);
      expect(current.paymentStatus, PaymentStatus.failed);

      // A retry with another card can still succeed.
      await store.apply(event('e2', order.id, PaymentEventType.succeeded));
      current = (await store.findOrder(order.id))!;
      expect(current.status, OrderStatus.received);
      expect(current.paymentStatus, PaymentStatus.succeeded);
    });

    test('an abandoned payment keeps the order waiting', () async {
      final store = newOrderStore();
      final order = await store.placeOrder(validRequest());

      await store.apply(event('e1', order.id, PaymentEventType.cancelled));

      final current = (await store.findOrder(order.id))!;
      expect(current.status, OrderStatus.pendingPayment);
      expect(current.paymentStatus, PaymentStatus.cancelled);
    });

    test('a late event for a cancelled order changes nothing', () async {
      final store = newOrderStore();
      final order = await store.placeOrder(validRequest());
      await store.cancelOrder(order.id);

      await store.apply(event('e1', order.id, PaymentEventType.succeeded));

      final current = (await store.findOrder(order.id))!;
      expect(current.status, OrderStatus.cancelled);
      expect(current.paymentStatus, PaymentStatus.pending);
    });

    test('an event for an unknown order is ignored', () async {
      final store = newOrderStore();

      await store.apply(event('e1', 'o-0', PaymentEventType.succeeded));

      expect(await store.watchOrders().first, isEmpty);
    });
  });

  group('cancelling', () {
    test('an unpaid order can be cancelled and stays unpaid', () async {
      final store = newOrderStore();
      final order = await store.placeOrder(validRequest());

      await store.cancelOrder(order.id);

      final current = (await store.findOrder(order.id))!;
      expect(current.status, OrderStatus.cancelled);
      expect(current.paymentStatus, PaymentStatus.pending);
    });

    test(
      'a paid order that has not started is cancelled and refunded',
      () async {
        final store = newOrderStore();
        final order = await store.placeOrder(validRequest());
        await store.apply(event('e1', order.id, PaymentEventType.succeeded));

        await store.cancelOrder(order.id);

        final current = (await store.findOrder(order.id))!;
        expect(current.status, OrderStatus.cancelled);
        expect(current.paymentStatus, PaymentStatus.refunded);
      },
    );

    test('the customer cannot cancel once the kitchen has started', () async {
      final store = newOrderStore();
      final order = await store.placeOrder(validRequest());
      await store.apply(event('e1', order.id, PaymentEventType.succeeded));
      await store.setStatus(order.id, OrderStatus.preparing);

      await expectLater(
        store.cancelOrder(order.id),
        throwsA(isA<OrderNotCancellableException>()),
      );
      expect((await store.findOrder(order.id))!.status, OrderStatus.preparing);
    });
  });

  group('operator status changes', () {
    test('walk the happy path step by step', () async {
      final store = newOrderStore();
      final order = await store.placeOrder(validRequest());
      await store.apply(event('e1', order.id, PaymentEventType.succeeded));

      for (final status in [
        OrderStatus.preparing,
        OrderStatus.outForDelivery,
        OrderStatus.delivered,
      ]) {
        await store.setStatus(order.id, status);
        expect((await store.findOrder(order.id))!.status, status);
      }
    });

    test(
      'cannot skip steps, go back, or mark an unpaid order as received',
      () async {
        final store = newOrderStore();
        final order = await store.placeOrder(validRequest());

        await expectLater(
          store.setStatus(order.id, OrderStatus.received),
          throwsA(isA<InvalidOrderTransitionException>()),
        );

        await store.apply(event('e1', order.id, PaymentEventType.succeeded));
        await expectLater(
          store.setStatus(order.id, OrderStatus.delivered),
          throwsA(isA<InvalidOrderTransitionException>()),
        );

        await store.setStatus(order.id, OrderStatus.preparing);
        await expectLater(
          store.setStatus(order.id, OrderStatus.received),
          throwsA(isA<InvalidOrderTransitionException>()),
        );
      },
    );

    test('a delivered or cancelled order is final', () async {
      final store = newOrderStore();
      final order = await store.placeOrder(validRequest());
      await store.cancelOrder(order.id);

      await expectLater(
        store.setStatus(order.id, OrderStatus.preparing),
        throwsA(isA<InvalidOrderTransitionException>()),
      );
    });

    test('the status helper follows the happy path', () {
      expect(OrderStatus.received.next, OrderStatus.preparing);
      expect(OrderStatus.preparing.next, OrderStatus.outForDelivery);
      expect(OrderStatus.outForDelivery.next, OrderStatus.delivered);
      expect(OrderStatus.delivered.next, isNull);
      expect(OrderStatus.pendingPayment.next, isNull);
      expect(OrderStatus.cancelled.next, isNull);
    });
  });

  group('watching', () {
    test('watchOrders emits the current list first, then every change, newest order first', () async {
      final store = newOrderStore();
      final emissions = <List<String>>[];
      final subscription = store.watchOrders().listen(
        (orders) => emissions.add([
          for (final o in orders) '${o.number}:${o.status.name}',
        ]),
      );

      final first = await store.placeOrder(validRequest(key: 'a'));
      await store.placeOrder(validRequest(key: 'b'));
      await store.apply(event('e1', first.id, PaymentEventType.succeeded));
      await pumpEventQueue();
      await subscription.cancel();

      expect(emissions, [
        <String>[],
        ['ZB-1001:pendingPayment'],
        ['ZB-1002:pendingPayment', 'ZB-1001:pendingPayment'],
        ['ZB-1002:pendingPayment', 'ZB-1001:received'],
      ]);
    });

    test(
      'watchOrder emits null for an unknown order and updates for a known one',
      () async {
        final store = newOrderStore();
        expect(await store.watchOrder('nope').first, isNull);

        final order = await store.placeOrder(validRequest());
        final statuses = <OrderStatus?>[];
        final subscription = store
            .watchOrder(order.id)
            .listen((o) => statuses.add(o?.status));
        await store.apply(event('e1', order.id, PaymentEventType.succeeded));
        await pumpEventQueue();
        await subscription.cancel();

        expect(statuses, [OrderStatus.pendingPayment, OrderStatus.received]);
      },
    );
  });
}
