import '../../orders/domain/order_status.dart';

/// One line of the audit log: what a staff member did.
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.at,
    required this.action,
    required this.entity,
    required this.entityId,
    required this.actorId,
    required this.details,
    this.fromStatus,
    this.toStatus,
  });

  final int id;
  final DateTime at;

  /// For example `order.set_status`.
  final String action;
  final String entity;
  final String? entityId;
  final String? actorId;
  final Map<String, dynamic> details;

  /// For a status change (`order.set_status`): the move that was made.
  final OrderStatus? fromStatus;
  final OrderStatus? toStatus;
}
