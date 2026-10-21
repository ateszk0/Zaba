import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/realtime/live_query.dart';
import '../../orders/data/order_status_codes.dart';
import '../../orders/data/supabase_order_repository.dart';
import '../../orders/domain/order.dart';
import '../../orders/domain/order_repository.dart';
import '../../orders/domain/order_status.dart';
import '../domain/admin_repository.dart';
import '../domain/audit_entry.dart';
import '../domain/order_history.dart';
import '../domain/staff.dart';

/// The admin page's view of Supabase. Row level security lets staff read every
/// order, and the database function `admin_set_order_status` checks the role
/// and the state machine and writes the audit log; this class asks, it never
/// decides.
class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<StaffRole?> currentRole() async {
    final row = await _client.from('admin_users').select('role').maybeSingle();
    return StaffRole.fromCode(row?['role']);
  }

  Future<Order?> _order(String id) async {
    final row = await _client
        .from('orders')
        .select(orderSelectColumns)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : orderFromRow(row);
  }

  @override
  Stream<List<Order>> watchOrders() => liveQuery(
    feed: realtimeChangeFeed(_client, table: 'orders'),
    fetch: () async {
      final rows = await _client
          .from('orders')
          .select(orderSelectColumns)
          .order('created_at', ascending: false)
          .limit(200);
      return rows.map(orderFromRow).toList(growable: false);
    },
  );

  @override
  Stream<Order?> watchOrder(String id) => liveQuery(
    feed: realtimeChangeFeed(
      _client,
      table: 'orders',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: id,
      ),
    ),
    fetch: () => _order(id),
  );

  @override
  Stream<List<StatusChange>> watchHistory(String orderId) => liveQuery(
    feed: realtimeChangeFeed(
      _client,
      table: 'order_status_history',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'order_id',
        value: orderId,
      ),
    ),
    fetch: () async {
      final rows = await _client
          .from('order_status_history')
          .select('id, from_status, to_status, actor, created_at')
          .eq('order_id', orderId)
          .order('id', ascending: true);
      return rows.map(statusChangeFromRow).toList(growable: false);
    },
  );

  @override
  Future<Map<OrderStatus, Set<OrderStatus>>> operatorTransitions() async {
    final rows = await _client
        .from('order_status_transitions')
        .select('from_status, to_status, allowed_actors');
    return operatorTransitionsFromRows(rows);
  }

  @override
  Future<void> setStatus(String orderId, OrderStatus status) async {
    try {
      await _client.rpc(
        'admin_set_order_status',
        params: {'p_order_id': orderId, 'p_status': orderStatusCode(status)},
      );
    } on PostgrestException catch (error) {
      if (error.message == 'forbidden' || error.code == '42501') {
        throw const StaffOnlyException();
      }
      if (error.message == 'invalid_transition') {
        final order = await _order(orderId);
        if (order != null) {
          throw InvalidOrderTransitionException(order.status, status);
        }
      }
      rethrow;
    }
  }

  @override
  Future<List<AuditEntry>> auditLog({int limit = 100}) async {
    final rows = await _client
        .from('audit_log')
        .select('id, created_at, actor_id, action, entity, entity_id, details')
        .order('id', ascending: false)
        .limit(limit);
    return rows.map(auditEntryFromRow).toList(growable: false);
  }
}

OrderStatus _status(Object? code) =>
    orderStatusFromCode(code) ??
    (throw FormatException('Unknown order status', code));

/// Only the moves an operator may make; the table also holds the payment
/// provider's and the customer's.
Map<OrderStatus, Set<OrderStatus>> operatorTransitionsFromRows(
  List<Map<String, dynamic>> rows,
) {
  final moves = <OrderStatus, Set<OrderStatus>>{};
  for (final row in rows) {
    final actors = (row['allowed_actors'] as List<dynamic>).cast<String>();
    if (actors.contains('operator')) {
      (moves[_status(row['from_status'])] ??= {}).add(
        _status(row['to_status']),
      );
    }
  }
  return moves;
}

StatusChange statusChangeFromRow(Map<String, dynamic> row) {
  final from = row['from_status'];
  final actor = switch (row['actor']) {
    'customer' => ChangeActor.customer,
    'operator' => ChangeActor.operator,
    'payment' => ChangeActor.payment,
    final other => throw FormatException('Unknown actor', other),
  };
  return StatusChange(
    from: from == null ? null : _status(from),
    to: _status(row['to_status']),
    actor: actor,
    at: DateTime.parse(row['created_at'] as String).toLocal(),
  );
}

AuditEntry auditEntryFromRow(Map<String, dynamic> row) {
  final details = (row['details'] as Map<String, dynamic>?) ?? const {};
  return AuditEntry(
    id: row['id'] as int,
    at: DateTime.parse(row['created_at'] as String).toLocal(),
    action: row['action'] as String,
    entity: row['entity'] as String,
    entityId: row['entity_id'] as String?,
    actorId: row['actor_id'] as String?,
    details: details,
    fromStatus: orderStatusFromCode(details['from']),
    toStatus: orderStatusFromCode(details['to']),
  );
}
