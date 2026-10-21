import '../../orders/domain/order_status.dart';

/// Who caused a status change.
enum ChangeActor { customer, operator, payment }

/// One row of an order's history.
class StatusChange {
  const StatusChange({
    required this.from,
    required this.to,
    required this.actor,
    required this.at,
  });

  /// Null for the first entry, when the order was placed.
  final OrderStatus? from;
  final OrderStatus to;
  final ChangeActor actor;
  final DateTime at;
}
