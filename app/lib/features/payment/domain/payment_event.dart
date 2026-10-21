enum PaymentEventType { succeeded, failed, cancelled }

/// What the payment provider reports about a payment attempt. On the real
/// backend this arrives as a signed webhook; it is the only thing that can
/// make an order paid.
class PaymentEvent {
  const PaymentEvent({
    required this.id,
    required this.orderId,
    required this.type,
  });

  /// Unique per event. A provider may deliver the same event more than once.
  final String id;
  final String orderId;
  final PaymentEventType type;
}

abstract interface class PaymentEventSink {
  /// Applies [event] exactly once: repeated deliveries of the same [PaymentEvent.id] change nothing.
  Future<void> apply(PaymentEvent event);
}
