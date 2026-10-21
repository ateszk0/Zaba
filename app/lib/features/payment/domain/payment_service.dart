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

/// The payment could not be started or reported (the network, the server). The
/// order is untouched by this: it still waits for payment and can be paid again.
class PaymentUnavailableException implements Exception {
  const PaymentUnavailableException([this.cause]);

  final Object? cause;

  @override
  String toString() => 'PaymentUnavailableException: $cause';
}
