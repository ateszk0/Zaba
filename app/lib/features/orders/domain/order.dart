import '../../../core/money/money.dart';
import '../../delivery/domain/delivery_address.dart';
import '../../delivery/domain/delivery_slot.dart';
import 'order_status.dart';

enum PaymentStatus { pending, succeeded, failed, cancelled, refunded }

/// A line of an order: a snapshot, so later menu changes do not alter it.
class OrderLine {
  const OrderLine({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  final String productId;
  final String name;
  final int quantity;
  final Money unitPrice;

  Money get total => unitPrice * quantity;
}

class Order {
  const Order({
    required this.id,
    required this.number,
    required this.placedAt,
    required this.lines,
    required this.subtotal,
    required this.deliveryFee,
    required this.address,
    required this.slot,
    required this.note,
    required this.status,
    required this.paymentStatus,
  });

  final String id;

  /// The human-readable order number, e.g. `ZB-1001`.
  final String number;
  final DateTime placedAt;
  final List<OrderLine> lines;
  final Money subtotal;
  final Money deliveryFee;
  final DeliveryAddress address;
  final DeliverySlot slot;
  final String note;
  final OrderStatus status;
  final PaymentStatus paymentStatus;

  Money get total => subtotal + deliveryFee;

  int get itemCount => lines.fold(0, (count, line) => count + line.quantity);

  Order copyWith({OrderStatus? status, PaymentStatus? paymentStatus}) => Order(
    id: id,
    number: number,
    placedAt: placedAt,
    lines: lines,
    subtotal: subtotal,
    deliveryFee: deliveryFee,
    address: address,
    slot: slot,
    note: note,
    status: status ?? this.status,
    paymentStatus: paymentStatus ?? this.paymentStatus,
  );
}
