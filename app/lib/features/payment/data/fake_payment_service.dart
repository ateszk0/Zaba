import '../../orders/domain/order.dart';
import '../../orders/domain/order_repository.dart';
import '../domain/card_outcome.dart';
import '../domain/payment_event.dart';
import '../domain/payment_service.dart';

/// Stands in for a card payment provider: it never sees card data, takes the
/// outcome of the card step, and reports it to the order backend as a payment
/// event, the way a provider's webhook would.
class FakePaymentService implements PaymentService {
  FakePaymentService({
    required this.sink,
    required this.orders,
    this.processingDelay = const Duration(milliseconds: 1200),
  });

  final PaymentEventSink sink;
  final OrderRepository orders;

  /// Simulated time the provider needs to process the payment.
  final Duration processingDelay;

  var _eventCounter = 0;

  @override
  Future<PaymentStatus> submit({
    required String orderId,
    required CardOutcome outcome,
  }) async {
    if (processingDelay > Duration.zero) {
      await Future<void>.delayed(processingDelay);
    }

    final type = switch (outcome) {
      CardOutcome.approved => PaymentEventType.succeeded,
      CardOutcome.declined => PaymentEventType.failed,
      CardOutcome.cancelled => PaymentEventType.cancelled,
    };
    _eventCounter++;
    await sink.apply(
      PaymentEvent(
        id: 'fake-$orderId-$_eventCounter',
        orderId: orderId,
        type: type,
      ),
    );

    final order = await orders.findOrder(orderId);
    return order?.paymentStatus ?? PaymentStatus.failed;
  }
}
