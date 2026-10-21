import '../../orders/domain/order.dart';
import '../../orders/domain/order_status.dart';
import 'audit_entry.dart';
import 'order_history.dart';
import 'staff.dart';

/// The signed-in person is not allowed to do this (not staff).
class StaffOnlyException implements Exception {
  const StaffOnlyException();

  @override
  String toString() => 'StaffOnlyException';
}

/// What the admin page can do. Reading is limited by the database to staff, and
/// so is every change: the page only offers what the database would accept.
abstract interface class AdminRepository {
  /// The role of the signed-in person, or null if they are not staff.
  Future<StaffRole?> currentRole();

  /// Every order, newest first; emits again on every change.
  Stream<List<Order>> watchOrders();

  Stream<Order?> watchOrder(String id);

  Stream<List<StatusChange>> watchHistory(String orderId);

  /// The moves an operator may make, as the database's state machine allows
  /// them: from a status to the statuses that may follow.
  Future<Map<OrderStatus, Set<OrderStatus>>> operatorTransitions();

  /// Throws [InvalidOrderTransitionException] for a move the state machine does
  /// not allow, [StaffOnlyException] for somebody who is not staff.
  Future<void> setStatus(String orderId, OrderStatus status);

  /// Newest first. Only an `admin` may read it.
  Future<List<AuditEntry>> auditLog({int limit = 100});
}
