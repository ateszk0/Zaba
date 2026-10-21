import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/features/orders/application/order_providers.dart';
import 'package:zaba/features/orders/domain/order.dart';
import 'package:zaba/features/orders/domain/order_repository.dart';
import 'package:zaba/features/payment/application/payment_providers.dart';
import 'package:zaba/features/payment/domain/card_outcome.dart';
import 'package:zaba/features/payment/domain/payment_service.dart';

import '../support/checkout_steps.dart';

/// An order backend that is down.
class DownOrders implements OrderRepository {
  var placeCalls = 0;

  @override
  Future<Order> placeOrder(PlaceOrderRequest request) async {
    placeCalls++;
    throw Exception('offline');
  }

  @override
  Future<Order?> findOrder(String id) async => null;

  @override
  Stream<List<Order>> watchOrders() => Stream.value(const []);

  @override
  Stream<Order?> watchOrder(String id) => Stream.value(null);

  @override
  Future<void> cancelOrder(String id) async {}
}

/// A payment backend that is down.
class DownPayments implements PaymentService {
  var calls = 0;

  @override
  Future<PaymentStatus> submit({
    required String orderId,
    required CardOutcome outcome,
  }) async {
    calls++;
    throw const PaymentUnavailableException('offline');
  }
}

void main() {
  testWidgets(
    'when the order backend is down the checkout says so and can try again',
    (tester) async {
      final orders = DownOrders();
      await reachCheckout(
        tester,
        overrides: [orderRepositoryProvider.overrideWithValue(orders)],
      );

      await placeOrder(tester);

      expect(
        find.text('A rendelést nem sikerült leadni. Próbáld meg újra.'),
        findsOneWidget,
      );
      // Still on the checkout, with the order button usable again.
      final button = find.widgetWithText(
        FilledButton,
        'Rendelés leadása · $total',
      );
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);

      await placeOrder(tester);
      expect(orders.placeCalls, 2);
    },
  );

  testWidgets(
    'when the payment backend is down the card screen says so, and the order stays payable',
    (tester) async {
      final payments = DownPayments();
      await reachCheckout(
        tester,
        overrides: [paymentServiceProvider.overrideWithValue(payments)],
      );
      await placeOrder(tester);
      await fillCard(tester);

      await pay(tester);

      expect(
        find.text(
          'A fizetést most nem sikerült elindítani. Ellenőrizd a kapcsolatot, és próbáld újra.',
        ),
        findsOneWidget,
      );
      expect(payments.calls, 1);
      // The card form is still there to try again.
      expect(
        find.widgetWithText(FilledButton, 'Fizetés · $total'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'cancelling the card step while the backend is down still leaves the screen',
    (tester) async {
      await reachCheckout(
        tester,
        overrides: [paymentServiceProvider.overrideWithValue(DownPayments())],
      );
      await placeOrder(tester);

      await tester.tap(find.text('Mégse'));
      await tester.pumpAndSettle();

      // On the order page, which still waits for payment.
      expect(find.text('Fizetésre vár'), findsWidgets);
    },
  );
}
