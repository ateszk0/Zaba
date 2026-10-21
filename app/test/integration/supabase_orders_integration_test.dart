@Tags(['integration'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zaba/core/realtime/live_query.dart';
import 'package:zaba/features/auth/data/supabase_auth_repository.dart';
import 'package:zaba/features/delivery/data/supabase_delivery_slot_service.dart';
import 'package:zaba/features/delivery/domain/delivery_address.dart';
import 'package:zaba/features/delivery/domain/delivery_slot.dart';
import 'package:zaba/features/orders/data/supabase_order_repository.dart';
import 'package:zaba/features/orders/domain/order.dart';
import 'package:zaba/features/orders/domain/order_repository.dart';
import 'package:zaba/features/orders/domain/order_status.dart';
import 'package:zaba/features/payment/data/supabase_payment_service.dart';
import 'package:zaba/features/payment/domain/card_outcome.dart';
import 'package:zaba/features/payment/domain/payment_service.dart';

import 'integration_env.dart';

// Placing and paying orders through the real repository and payment service,
// against a real Supabase whose Edge Functions have their provider secret (see
// supabase/.env.example). The customer's whole path, with the live updates.

var _counter = 0;

void main() {
  late SupabaseClient client;
  late SupabaseOrderRepository orders;
  late SupabasePaymentService payments;
  late List<DeliverySlot> slots;

  setUpAll(() {
    // flutter_test answers every HTTP request with an error; this test needs the
    // real network.
    HttpOverrides.global = null;
  });

  setUp(() async {
    client = newIntegrationClient();
    orders = SupabaseOrderRepository(client);
    payments = SupabasePaymentService(
      client,
      orders: orders,
      processingDelay: Duration.zero,
    );
    await SupabaseAuthRepository(client.auth).signUp(
      email: 'order-${DateTime.now().microsecondsSinceEpoch}@example.test',
      password: 'hosszu-jelszo-1',
    );
    final days = await SupabaseDeliverySlotService(client)
        .availableDays(now: DateTime.now());
    slots = [for (final day in days) ...day.slots];
  });
  tearDown(() => client.dispose());

  PlaceOrderRequest request({
    DeliverySlot? slot,
    Map<String, int> lines = const {'carbonara': 2},
    String postalCode = '1051',
    String? key,
  }) => PlaceOrderRequest(
    idempotencyKey:
        key ?? 'it-${DateTime.now().microsecondsSinceEpoch}-${_counter++}',
    lines: lines,
    address: DeliveryAddress(postalCode: postalCode, street: 'Váci utca 12.'),
    slot: slot ?? slots[_counter % slots.length],
    note: 'Csengess kétszer.',
  );

  Matcher rejectedWith(OrderRejection reason) => throwsA(
    isA<OrderRejectedException>().having((e) => e.reason, 'reason', reason),
  );

  group('placing an order', () {
    test(
      'creates an order that waits for payment, with its lines and window',
      () async {
        final slot = slots.first;
        final order = await orders.placeOrder(request(slot: slot));

        expect(order.number, startsWith('ZB-'));
        expect(order.status, OrderStatus.pendingPayment);
        expect(order.paymentStatus, PaymentStatus.pending);
        expect(order.total.forint, 6570);
        expect(order.note, 'Csengess kétszer.');
        expect(order.address.street, 'Váci utca 12.');
        expect(order.lines.single.productId, 'carbonara');
        expect(order.lines.single.quantity, 2);
        expect(order.lines.single.unitPrice.forint, 2790);
        expect(order.slot, slot);
        expect(await orders.findOrder(order.id), isNotNull);
      },
    );

    test('the same key gives the same order, not a second one', () async {
      final first = request();
      final a = await orders.placeOrder(first);
      final b = await orders.placeOrder(first);

      expect(b.id, a.id);
      final list = await orders.watchOrders().first;
      expect(list.where((o) => o.id == a.id), hasLength(1));
    });

    test(
      'the server\'s refusals arrive as the reasons the checkout knows',
      () async {
        await expectLater(
          orders.placeOrder(request(postalCode: '2000')),
          rejectedWith(OrderRejection.outOfDeliveryArea),
        );
        await expectLater(
          orders.placeOrder(request(lines: {'lemonade': 1})),
          rejectedWith(OrderRejection.belowMinimumOrder),
        );
        await expectLater(
          orders.placeOrder(request(lines: const {})),
          rejectedWith(OrderRejection.emptyCart),
        );
        await expectLater(
          orders.placeOrder(
            request(
              slot: DeliverySlot(
                id: '00000000-0000-4000-8000-000000000000',
                start: slots.first.start,
                end: slots.first.end,
              ),
            ),
          ),
          rejectedWith(OrderRejection.slotUnavailable),
        );
      },
    );

    test('a customer cannot hold more than five unpaid orders, and cancelling one frees the limit', () async {
      final first = await orders.placeOrder(request());
      for (var i = 0; i < maxUnpaidOrders - 1; i++) {
        await orders.placeOrder(request());
      }

      await expectLater(
        orders.placeOrder(request()),
        rejectedWith(OrderRejection.tooManyUnpaidOrders),
      );

      await orders.cancelOrder(first.id);
      expect(
        (await orders.placeOrder(request())).status,
        OrderStatus.pendingPayment,
      );
    });

    test('an order is only visible to the customer who placed it', () async {
      final mine = await orders.placeOrder(request());

      final other = newIntegrationClient();
      addTearDown(other.dispose);
      await SupabaseAuthRepository(other.auth).signUp(
        email: 'other-${DateTime.now().microsecondsSinceEpoch}@example.test',
        password: 'hosszu-jelszo-1',
      );
      final theirs = SupabaseOrderRepository(other);

      expect(await theirs.findOrder(mine.id), isNull);
      expect(await theirs.watchOrders().first, isEmpty);
      await expectLater(
        SupabasePaymentService(
          other,
          orders: theirs,
          processingDelay: Duration.zero,
        ).submit(orderId: mine.id, outcome: CardOutcome.approved),
        throwsA(isA<PaymentUnavailableException>()),
      );
      expect(
        (await orders.findOrder(mine.id))!.status,
        OrderStatus.pendingPayment,
      );
    });
  }, skip: integrationSkip);

  group('paying', () {
    test(
      'an approved card pays the order, through the provider\'s event',
      () async {
        final order = await orders.placeOrder(request());

        final status = await payments.submit(
          orderId: order.id,
          outcome: CardOutcome.approved,
        );

        expect(status, PaymentStatus.succeeded);
        final paid = (await orders.findOrder(order.id))!;
        expect(paid.status, OrderStatus.received);
        expect(paid.paymentStatus, PaymentStatus.succeeded);
      },
    );

    test(
      'a declined card leaves the order waiting, and a retry can pay it',
      () async {
        final order = await orders.placeOrder(request());

        expect(
          await payments.submit(
            orderId: order.id,
            outcome: CardOutcome.declined,
          ),
          PaymentStatus.failed,
        );
        expect(
          (await orders.findOrder(order.id))!.status,
          OrderStatus.pendingPayment,
        );

        expect(
          await payments.submit(
            orderId: order.id,
            outcome: CardOutcome.approved,
          ),
          PaymentStatus.succeeded,
        );
        expect(
          (await orders.findOrder(order.id))!.status,
          OrderStatus.received,
        );
      },
    );

    test(
      'cancelling the card step is recorded and leaves the order payable',
      () async {
        final order = await orders.placeOrder(request());

        expect(
          await payments.submit(
            orderId: order.id,
            outcome: CardOutcome.cancelled,
          ),
          PaymentStatus.cancelled,
        );
        expect(
          (await orders.findOrder(order.id))!.status,
          OrderStatus.pendingPayment,
        );
      },
    );

    test('a paid order that is already paid cannot be paid again', () async {
      final order = await orders.placeOrder(request());
      await payments.submit(orderId: order.id, outcome: CardOutcome.approved);

      await expectLater(
        payments.submit(orderId: order.id, outcome: CardOutcome.approved),
        throwsA(isA<PaymentUnavailableException>()),
      );
    });
  }, skip: integrationSkip);

  group('cancelling', () {
    test('an unpaid order can be cancelled', () async {
      final order = await orders.placeOrder(request());
      await orders.cancelOrder(order.id);

      final cancelled = (await orders.findOrder(order.id))!;
      expect(cancelled.status, OrderStatus.cancelled);
      expect(cancelled.paymentStatus, PaymentStatus.pending);
    });

    test('a paid order is cancelled and refunded', () async {
      final order = await orders.placeOrder(request());
      await payments.submit(orderId: order.id, outcome: CardOutcome.approved);
      await orders.cancelOrder(order.id);

      final cancelled = (await orders.findOrder(order.id))!;
      expect(cancelled.status, OrderStatus.cancelled);
      expect(cancelled.paymentStatus, PaymentStatus.refunded);
    });

    test(
      'an order that is already cancelled cannot be cancelled again',
      () async {
        final order = await orders.placeOrder(request());
        await orders.cancelOrder(order.id);

        await expectLater(
          orders.cancelOrder(order.id),
          throwsA(
            isA<OrderNotCancellableException>().having(
              (e) => e.status,
              'status',
              OrderStatus.cancelled,
            ),
          ),
        );
      },
    );
  }, skip: integrationSkip);

  group('following an order live', () {
    test('the customer sees the payment arrive without asking again', () async {
      final order = await orders.placeOrder(request());
      final seen = <OrderStatus>[];
      final subscription = orders.watchOrder(order.id).listen((o) {
        if (o != null && (seen.isEmpty || seen.last != o.status)) {
          seen.add(o.status);
        }
      });
      addTearDown(subscription.cancel);
      // Wait for the first value and the live connection.
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(seen, [OrderStatus.pendingPayment]);

      await payments.submit(orderId: order.id, outcome: CardOutcome.approved);

      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (!seen.contains(OrderStatus.received) &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(seen, [OrderStatus.pendingPayment, OrderStatus.received]);
    });

    test(
      'the live connection itself comes up and reports a change quickly',
      () async {
        // Not the polling fallback: this listens to Realtime directly.
        final live = Completer<void>();
        final changed = Completer<void>();
        final stop = realtimeChangeFeed(client, table: 'orders')(
          onChange: () {
            if (!changed.isCompleted) changed.complete();
          },
          onStatus: (isLive) {
            if (isLive && !live.isCompleted) live.complete();
          },
        );
        addTearDown(stop);
        await live.future.timeout(const Duration(seconds: 10));
        // The server finishes setting up a moment after it says "subscribed".
        await Future<void>.delayed(const Duration(seconds: 2));

        await orders.placeOrder(request());

        await changed.future.timeout(const Duration(seconds: 4));
      },
    );

    test('the list follows new orders', () async {
      final lists = <List<Order>>[];
      final subscription = orders.watchOrders().listen(lists.add);
      addTearDown(subscription.cancel);
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(lists.last, isEmpty);

      final order = await orders.placeOrder(request());

      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (lists.last.isEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(lists.last.map((o) => o.id), [order.id]);
    });
  }, skip: integrationSkip);
}
