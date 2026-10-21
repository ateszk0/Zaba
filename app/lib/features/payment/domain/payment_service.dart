import '../../orders/domain/order.dart';
import 'card_outcome.dart';

abstract interface class PaymentService {
  /// Reports the outcome of the card step for [orderId] and returns the
  /// payment status the order ends up with. The order itself only changes
  /// through the provider's event on the backend.
  Future<PaymentStatus> submit({
    required String orderId,
    required CardOutcome outcome,
  });
}
