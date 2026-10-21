import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../orders/domain/order.dart';
import '../../orders/domain/order_status.dart';
import '../domain/admin_repository.dart';
import '../domain/audit_entry.dart';
import '../domain/order_history.dart';
import '../domain/staff.dart';

/// `main_admin.dart` supplies the Supabase implementation. The admin page has no
/// offline mode: two separate apps cannot share in-memory orders.
final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => throw UnimplementedError('The admin page needs a backend.'),
);

/// The role of whoever is signed in; null when nobody is, or when they are not
/// staff. Re-asked when somebody else signs in.
final staffRoleProvider = FutureProvider<StaffRole?>((ref) async {
  if (ref.watch(sessionProvider) == null) {
    return null;
  }
  return ref.watch(adminRepositoryProvider).currentRole();
});

final adminOrdersProvider = StreamProvider<List<Order>>((ref) {
  if (ref.watch(sessionProvider) == null) {
    return Stream.value(const <Order>[]);
  }
  return ref.watch(adminRepositoryProvider).watchOrders();
});

final adminOrderProvider = StreamProvider.family<Order?, String>((ref, id) {
  if (ref.watch(sessionProvider) == null) {
    return Stream.value(null);
  }
  return ref.watch(adminRepositoryProvider).watchOrder(id);
});

final orderHistoryProvider = StreamProvider.family<List<StatusChange>, String>((
  ref,
  id,
) {
  if (ref.watch(sessionProvider) == null) {
    return Stream.value(const <StatusChange>[]);
  }
  return ref.watch(adminRepositoryProvider).watchHistory(id);
});

/// From a status to the statuses an operator may move the order to.
final operatorTransitionsProvider =
    FutureProvider<Map<OrderStatus, Set<OrderStatus>>>(
      (ref) => ref.watch(adminRepositoryProvider).operatorTransitions(),
    );

final auditLogProvider = FutureProvider.autoDispose<List<AuditEntry>>(
  (ref) => ref.watch(adminRepositoryProvider).auditLog(),
);

/// Which orders the list shows.
enum AdminOrderFilter {
  /// Paid and not finished: what the kitchen works on.
  active,
  awaitingPayment,
  closed,
  all;

  bool matches(OrderStatus status) => switch (this) {
    AdminOrderFilter.active =>
      status == OrderStatus.received ||
          status == OrderStatus.preparing ||
          status == OrderStatus.outForDelivery,
    AdminOrderFilter.awaitingPayment => status == OrderStatus.pendingPayment,
    AdminOrderFilter.closed =>
      status == OrderStatus.delivered || status == OrderStatus.cancelled,
    AdminOrderFilter.all => true,
  };
}

/// The orders of [filter], in the order the kitchen needs them: work in
/// progress by delivery window (the earliest first), finished ones newest first.
List<Order> filterAdminOrders(List<Order> orders, AdminOrderFilter filter) {
  final selected = [
    for (final order in orders)
      if (filter.matches(order.status)) order,
  ];
  switch (filter) {
    case AdminOrderFilter.active:
    case AdminOrderFilter.awaitingPayment:
      selected.sort((a, b) {
        final bySlot = a.slot.start.compareTo(b.slot.start);
        return bySlot != 0 ? bySlot : a.placedAt.compareTo(b.placedAt);
      });
    case AdminOrderFilter.closed:
    case AdminOrderFilter.all:
      selected.sort((a, b) => b.placedAt.compareTo(a.placedAt));
  }
  return selected;
}

class AdminOrderFilterNotifier extends Notifier<AdminOrderFilter> {
  @override
  AdminOrderFilter build() => AdminOrderFilter.active;

  void select(AdminOrderFilter filter) => state = filter;
}

final adminOrderFilterProvider =
    NotifierProvider<AdminOrderFilterNotifier, AdminOrderFilter>(
      AdminOrderFilterNotifier.new,
    );
