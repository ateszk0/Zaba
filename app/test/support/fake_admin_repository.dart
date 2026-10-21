import 'dart:async';

import 'package:zaba/features/admin/domain/admin_repository.dart';
import 'package:zaba/features/admin/domain/audit_entry.dart';
import 'package:zaba/features/admin/domain/order_history.dart';
import 'package:zaba/features/admin/domain/staff.dart';
import 'package:zaba/features/orders/data/order_status_codes.dart';
import 'package:zaba/features/orders/domain/order.dart';
import 'package:zaba/features/orders/domain/order_repository.dart';
import 'package:zaba/features/orders/domain/order_status.dart';

import 'order_fixtures.dart';

/// The moves an operator may make, as the database's table has them.
const operatorMoves = <OrderStatus, Set<OrderStatus>>{
  OrderStatus.pendingPayment: {OrderStatus.cancelled},
  OrderStatus.received: {OrderStatus.preparing, OrderStatus.cancelled},
  OrderStatus.preparing: {OrderStatus.outForDelivery, OrderStatus.cancelled},
  OrderStatus.outForDelivery: {OrderStatus.delivered},
};

/// A stand-in for the backend of the admin page: it keeps orders in memory,
/// applies the moves of [operatorMoves], records history and audit entries, and
/// can be told to fail.
class FakeAdminRepository implements AdminRepository {
  FakeAdminRepository({
    this.role = StaffRole.operator,
    List<Order> orders = const [],
  }) : _orders = List.of(orders);

  /// The role of whoever asks; null means "not staff".
  StaffRole? role;

  /// What `setStatus` throws instead of working, once.
  Exception? failNextMove;

  final List<Order> _orders;
  final _history = <String, List<StatusChange>>{};
  final audit = <AuditEntry>[];
  final _changes = StreamController<void>.broadcast(sync: true);
  var setStatusCalls = <(String, OrderStatus)>[];

  void put(Order order) {
    final index = _orders.indexWhere((o) => o.id == order.id);
    if (index < 0) {
      _orders.add(order);
    } else {
      _orders[index] = order;
    }
    _changes.add(null);
  }

  Stream<T> _live<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  @override
  Future<StaffRole?> currentRole() async => role;

  @override
  Stream<List<Order>> watchOrders() => _live(
    () => List.unmodifiable(
      [..._orders]..sort((a, b) => b.placedAt.compareTo(a.placedAt)),
    ),
  );

  @override
  Stream<Order?> watchOrder(String id) =>
      _live(() => _orders.where((o) => o.id == id).firstOrNull);

  @override
  Stream<List<StatusChange>> watchHistory(String orderId) =>
      _live(() => List.unmodifiable(_history[orderId] ?? const []));

  @override
  Future<Map<OrderStatus, Set<OrderStatus>>> operatorTransitions() async =>
      operatorMoves;

  @override
  Future<void> setStatus(String orderId, OrderStatus status) async {
    setStatusCalls = [...setStatusCalls, (orderId, status)];
    final failure = failNextMove;
    if (failure != null) {
      failNextMove = null;
      throw failure;
    }
    if (role == null) {
      throw const StaffOnlyException();
    }
    final order = _orders.firstWhere((o) => o.id == orderId);
    if (!(operatorMoves[order.status]?.contains(status) ?? false)) {
      throw InvalidOrderTransitionException(order.status, status);
    }
    final refunded =
        status == OrderStatus.cancelled &&
        order.paymentStatus == PaymentStatus.succeeded;
    put(
      order.copyWith(
        status: status,
        paymentStatus: refunded ? PaymentStatus.refunded : null,
      ),
    );
    (_history[orderId] ??= []).add(
      StatusChange(
        from: order.status,
        to: status,
        actor: ChangeActor.operator,
        at: fixedNow,
      ),
    );
    audit.insert(
      0,
      AuditEntry(
        id: audit.length + 1,
        at: fixedNow,
        action: 'order.set_status',
        entity: 'orders',
        entityId: orderId,
        actorId: 'staff-1',
        details: {
          'from': orderStatusCode(order.status),
          'to': orderStatusCode(status),
        },
        fromStatus: order.status,
        toStatus: status,
      ),
    );
  }

  @override
  Future<List<AuditEntry>> auditLog({int limit = 100}) async =>
      List.unmodifiable(audit);
}
