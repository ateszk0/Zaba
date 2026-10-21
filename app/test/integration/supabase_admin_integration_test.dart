@Tags(['integration'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zaba/features/admin/data/supabase_admin_repository.dart';
import 'package:zaba/features/admin/domain/admin_repository.dart';
import 'package:zaba/features/admin/domain/order_history.dart';
import 'package:zaba/features/admin/domain/staff.dart';
import 'package:zaba/features/auth/data/supabase_auth_repository.dart';
import 'package:zaba/features/delivery/data/supabase_delivery_slot_service.dart';
import 'package:zaba/features/delivery/domain/delivery_address.dart';
import 'package:zaba/features/orders/data/supabase_order_repository.dart';
import 'package:zaba/features/orders/domain/order.dart';
import 'package:zaba/features/orders/domain/order_repository.dart';
import 'package:zaba/features/orders/domain/order_status.dart';
import 'package:zaba/features/payment/data/supabase_payment_service.dart';
import 'package:zaba/features/payment/domain/card_outcome.dart';

import 'integration_env.dart';

// The admin page's repository against a real Supabase: a customer places and
// pays orders, staff accounts (made with the secret key) work on them. Needs the
// Edge Functions with their secret, like the orders test.

var _counter = 0;

void main() {
  late SupabaseClient customer;
  late SupabaseOrderRepository orders;
  late SupabasePaymentService payments;
  late SupabaseAdminRepository operator;
  late SupabaseAdminRepository admin;
  late List<SupabaseClient> clients;
  late List<dynamic> slots;

  setUpAll(() {
    // flutter_test answers every HTTP request with an error; this test needs the
    // real network.
    HttpOverrides.global = null;
  });

  setUp(() async {
    customer = newIntegrationClient();
    await SupabaseAuthRepository(customer.auth).signUp(
      email: 'cust-${DateTime.now().microsecondsSinceEpoch}@example.test',
      password: 'hosszu-jelszo-1',
    );
    orders = SupabaseOrderRepository(customer);
    payments = SupabasePaymentService(
      customer,
      orders: orders,
      processingDelay: Duration.zero,
    );
    final staffOperator = await newStaffClient(StaffRole.operator);
    final staffAdmin = await newStaffClient(StaffRole.admin);
    operator = SupabaseAdminRepository(staffOperator);
    admin = SupabaseAdminRepository(staffAdmin);
    clients = [customer, staffOperator, staffAdmin];
    final days = await SupabaseDeliverySlotService(customer)
        .availableDays(now: DateTime.now());
    slots = [for (final day in days) ...day.slots];
  });
  tearDown(() {
    for (final client in clients) {
      client.dispose();
    }
  });

  Future<Order> paidOrder() async {
    final order = await orders.placeOrder(
      PlaceOrderRequest(
        idempotencyKey:
            'adm-${DateTime.now().microsecondsSinceEpoch}-${_counter++}',
        lines: const {'carbonara': 2},
        address: const DeliveryAddress(
          postalCode: '1051',
          street: 'Váci utca 12.',
        ),
        slot: slots[_counter % slots.length],
        note: 'Admin teszt',
      ),
    );
    await payments.submit(orderId: order.id, outcome: CardOutcome.approved);
    return (await orders.findOrder(order.id))!;
  }

  group('who is staff', () {
    test('the role comes from the staff table', () async {
      expect(await operator.currentRole(), StaffRole.operator);
      expect(await admin.currentRole(), StaffRole.admin);
      expect(await SupabaseAdminRepository(customer).currentRole(), isNull);
    });

    test(
      'the moves of an operator are the database\'s state machine',
      () async {
        expect(await operator.operatorTransitions(), {
          OrderStatus.pendingPayment: {OrderStatus.cancelled},
          OrderStatus.received: {OrderStatus.preparing, OrderStatus.cancelled},
          OrderStatus.preparing: {
            OrderStatus.outForDelivery,
            OrderStatus.cancelled,
          },
          OrderStatus.outForDelivery: {OrderStatus.delivered},
        });
      },
    );
  }, skip: staffIntegrationSkip);

  group('working on orders', () {
    test('staff see the customer\'s order and its history, a customer sees only their own', () async {
      final order = await paidOrder();

      final seen = await operator.watchOrders().first;
      expect(seen.map((o) => o.id), contains(order.id));
      expect(
        (await operator.watchOrder(order.id).first)?.status,
        OrderStatus.received,
      );

      final history = await operator.watchHistory(order.id).first;
      expect(history.map((c) => (c.from, c.to, c.actor)), [
        (null, OrderStatus.pendingPayment, ChangeActor.customer),
        (OrderStatus.pendingPayment, OrderStatus.received, ChangeActor.payment),
      ]);

      // The customer, through the same repository, sees nothing beyond their own.
      final own = await SupabaseAdminRepository(customer).watchOrders().first;
      expect(own.map((o) => o.id), [order.id]);
    });

    test('an operator moves the order, the customer sees it, history and audit follow', () async {
      final order = await paidOrder();

      await operator.setStatus(order.id, OrderStatus.preparing);

      expect((await orders.findOrder(order.id))!.status, OrderStatus.preparing);
      final history = await operator.watchHistory(order.id).first;
      expect(history.last.to, OrderStatus.preparing);
      expect(history.last.actor, ChangeActor.operator);

      final entries = await admin.auditLog();
      final entry = entries.firstWhere((e) => e.entityId == order.id);
      expect(entry.action, 'order.set_status');
      expect(entry.details, {'from': 'received', 'to': 'preparing'});
    });

    test('only an administrator reads the audit log', () async {
      final order = await paidOrder();
      await operator.setStatus(order.id, OrderStatus.preparing);

      expect(await operator.auditLog(), isEmpty);
      expect(await SupabaseAdminRepository(customer).auditLog(), isEmpty);
      expect(await admin.auditLog(), isNotEmpty);
    });

    test('a move the state machine does not allow is refused with the status it is in', () async {
      final order = await paidOrder();
      await operator.setStatus(order.id, OrderStatus.preparing);

      await expectLater(
        operator.setStatus(order.id, OrderStatus.delivered),
        throwsA(
          isA<InvalidOrderTransitionException>()
              .having((e) => e.from, 'from', OrderStatus.preparing)
              .having((e) => e.to, 'to', OrderStatus.delivered),
        ),
      );
      // An order cannot be marked as paid by hand either.
      final unpaid = await orders.placeOrder(
        PlaceOrderRequest(
          idempotencyKey:
              'adm-${DateTime.now().microsecondsSinceEpoch}-${_counter++}',
          lines: const {'carbonara': 2},
          address: const DeliveryAddress(
            postalCode: '1051',
            street: 'Váci utca 12.',
          ),
          slot: slots[_counter % slots.length],
        ),
      );
      await expectLater(
        operator.setStatus(unpaid.id, OrderStatus.received),
        throwsA(isA<InvalidOrderTransitionException>()),
      );
    });

    test('somebody who is not staff cannot move an order', () async {
      final order = await paidOrder();

      await expectLater(
        SupabaseAdminRepository(customer)
            .setStatus(order.id, OrderStatus.preparing),
        throwsA(isA<StaffOnlyException>()),
      );
      expect((await orders.findOrder(order.id))!.status, OrderStatus.received);
    });

    test('cancelling a paid order refunds it', () async {
      final order = await paidOrder();

      await operator.setStatus(order.id, OrderStatus.cancelled);

      final cancelled = (await orders.findOrder(order.id))!;
      expect(cancelled.status, OrderStatus.cancelled);
      expect(cancelled.paymentStatus, PaymentStatus.refunded);
    });

    test('an order goes all the way to delivered', () async {
      final order = await paidOrder();

      for (final next in [
        OrderStatus.preparing,
        OrderStatus.outForDelivery,
        OrderStatus.delivered,
      ]) {
        await operator.setStatus(order.id, next);
      }

      expect((await orders.findOrder(order.id))!.status, OrderStatus.delivered);
      expect(
        await operator.operatorTransitions().then(
          (m) => m[OrderStatus.delivered],
        ),
        isNull,
      );
    });
  }, skip: staffIntegrationSkip);
}
