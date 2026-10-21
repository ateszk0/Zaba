import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/features/admin/admin_router.dart';
import 'package:zaba/features/admin/application/admin_providers.dart';
import 'package:zaba/features/admin/data/supabase_admin_repository.dart';
import 'package:zaba/features/orders/data/order_status_codes.dart';
import 'package:zaba/features/admin/domain/order_history.dart';
import 'package:zaba/features/admin/domain/staff.dart';
import 'package:zaba/features/delivery/domain/delivery_slot.dart';
import 'package:zaba/features/orders/domain/order_status.dart';

import '../../support/order_fixtures.dart';

DeliverySlot slotAt(int hour) => DeliverySlot(
  id: 'slot-$hour',
  start: DateTime(2026, 10, 21, hour),
  end: DateTime(2026, 10, 21, hour + 1),
);

void main() {
  group('the order list', () {
    final orders = [
      sampleOrder(
        id: 'late',
        status: OrderStatus.received,
        slot: slotAt(19),
        placedAt: DateTime(2026, 10, 21, 9),
      ),
      sampleOrder(
        id: 'early',
        status: OrderStatus.preparing,
        slot: slotAt(12),
        placedAt: DateTime(2026, 10, 21, 11),
      ),
      sampleOrder(
        id: 'same-slot-first',
        status: OrderStatus.outForDelivery,
        slot: slotAt(12),
        placedAt: DateTime(2026, 10, 21, 8),
      ),
      sampleOrder(
        id: 'unpaid',
        status: OrderStatus.pendingPayment,
        slot: slotAt(15),
      ),
      sampleOrder(
        id: 'done-old',
        status: OrderStatus.delivered,
        placedAt: DateTime(2026, 10, 20, 12),
      ),
      sampleOrder(
        id: 'cancelled-new',
        status: OrderStatus.cancelled,
        placedAt: DateTime(2026, 10, 21, 10),
      ),
    ];
    List<String> ids(AdminOrderFilter filter) =>
        filterAdminOrders(orders, filter).map((o) => o.id).toList();

    test(
      'active shows paid, unfinished orders, earliest delivery window first',
      () {
        expect(ids(AdminOrderFilter.active), [
          'same-slot-first',
          'early',
          'late',
        ]);
      },
    );

    test('awaiting payment shows only the unpaid ones', () {
      expect(ids(AdminOrderFilter.awaitingPayment), ['unpaid']);
    });

    test('closed shows delivered and cancelled orders, newest first', () {
      expect(ids(AdminOrderFilter.closed), ['cancelled-new', 'done-old']);
    });

    test('all shows everything, newest first', () {
      expect(ids(AdminOrderFilter.all), hasLength(6));
      final placed = filterAdminOrders(
        orders,
        AdminOrderFilter.all,
      ).map((o) => o.placedAt).toList();
      expect(placed, [...placed]..sort((a, b) => b.compareTo(a)));
    });

    test('every status belongs to at least one of the named filters', () {
      for (final status in OrderStatus.values) {
        expect(
          [
            AdminOrderFilter.active,
            AdminOrderFilter.awaitingPayment,
            AdminOrderFilter.closed,
          ].where((filter) => filter.matches(status)),
          hasLength(1),
          reason: '$status',
        );
      }
    });
  });

  group('rows from the database', () {
    test('the operator moves are read from the state machine table', () {
      final moves = operatorTransitionsFromRows([
        {
          'from_status': 'pending_payment',
          'to_status': 'received',
          'allowed_actors': ['payment'],
        },
        {
          'from_status': 'pending_payment',
          'to_status': 'cancelled',
          'allowed_actors': ['customer', 'operator'],
        },
        {
          'from_status': 'received',
          'to_status': 'preparing',
          'allowed_actors': ['operator'],
        },
        {
          'from_status': 'received',
          'to_status': 'cancelled',
          'allowed_actors': ['customer', 'operator'],
        },
        {
          'from_status': 'preparing',
          'to_status': 'out_for_delivery',
          'allowed_actors': ['operator'],
        },
        {
          'from_status': 'out_for_delivery',
          'to_status': 'delivered',
          'allowed_actors': ['operator'],
        },
      ]);

      expect(moves, {
        OrderStatus.pendingPayment: {OrderStatus.cancelled},
        OrderStatus.received: {OrderStatus.preparing, OrderStatus.cancelled},
        OrderStatus.preparing: {OrderStatus.outForDelivery},
        OrderStatus.outForDelivery: {OrderStatus.delivered},
      });
    });

    test('a history row says who moved the order', () {
      final first = statusChangeFromRow({
        'from_status': null,
        'to_status': 'pending_payment',
        'actor': 'customer',
        'created_at': '2026-10-21T08:30:00+00:00',
      });
      expect(first.from, isNull);
      expect(first.to, OrderStatus.pendingPayment);
      expect(first.actor, ChangeActor.customer);

      final paid = statusChangeFromRow({
        'from_status': 'pending_payment',
        'to_status': 'received',
        'actor': 'payment',
        'created_at': '2026-10-21T08:31:00+00:00',
      });
      expect(paid.actor, ChangeActor.payment);
      expect(paid.from, OrderStatus.pendingPayment);
      expect(
        () => statusChangeFromRow({
          'from_status': null,
          'to_status': 'received',
          'actor': 'robot',
          'created_at': '2026-10-21T08:31:00+00:00',
        }),
        throwsFormatException,
      );
    });

    test('an audit row keeps what the database logged', () {
      final entry = auditEntryFromRow({
        'id': 7,
        'created_at': '2026-10-21T08:31:00+00:00',
        'actor_id': 'abc',
        'action': 'order.set_status',
        'entity': 'orders',
        'entity_id': 'o-1',
        'details': {'from': 'received', 'to': 'preparing'},
      });
      expect(entry.id, 7);
      expect(entry.action, 'order.set_status');
      expect(entry.details, {'from': 'received', 'to': 'preparing'});
      expect(entry.fromStatus, OrderStatus.received);
      expect(entry.toStatus, OrderStatus.preparing);
    });

    test('every status has a database word that reads back', () {
      for (final status in OrderStatus.values) {
        final row = statusChangeFromRow({
          'from_status': null,
          'to_status': orderStatusCode(status),
          'actor': 'operator',
          'created_at': '2026-10-21T08:31:00+00:00',
        });
        expect(row.to, status);
      }
    });

    test('an audit row of another kind has no status move', () {
      final entry = auditEntryFromRow({
        'id': 8,
        'created_at': '2026-10-21T08:31:00+00:00',
        'actor_id': null,
        'action': 'something.else',
        'entity': 'things',
        'entity_id': null,
        'details': <String, dynamic>{},
      });
      expect(entry.fromStatus, isNull);
      expect(entry.toStatus, isNull);
    });

    test('an unknown status word is not guessed', () {
      expect(orderStatusFromCode('teleported'), isNull);
      expect(orderStatusFromCode(null), isNull);
    });

    test('roles are read from their code, anything else is no role', () {
      expect(StaffRole.fromCode('admin'), StaffRole.admin);
      expect(StaffRole.fromCode('operator'), StaffRole.operator);
      expect(StaffRole.fromCode('manager'), isNull);
      expect(StaffRole.fromCode(null), isNull);
    });
  });

  group('the admin router', () {
    test(
      'sends a guest to the sign-in and a signed-in person away from it',
      () {
        expect(adminRedirect(signedIn: false, path: '/'), '/login');
        expect(adminRedirect(signedIn: false, path: '/orders/abc'), '/login');
        expect(adminRedirect(signedIn: false, path: '/login'), isNull);
        expect(adminRedirect(signedIn: true, path: '/login'), '/');
        expect(adminRedirect(signedIn: true, path: '/'), isNull);
        expect(adminRedirect(signedIn: true, path: '/audit'), isNull);
      },
    );
  });
}
