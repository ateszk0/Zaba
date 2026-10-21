enum OrderStatus {
  /// Placed but not paid yet. The kitchen does not start before payment.
  pendingPayment,
  received,
  preparing,
  outForDelivery,
  delivered,
  cancelled;

  /// The happy path after payment, in order. Drives the progress timeline.
  static const timeline = [received, preparing, outForDelivery, delivered];

  /// The next step on the happy path; null when there is none.
  OrderStatus? get next {
    final index = timeline.indexOf(this);
    if (index < 0 || index == timeline.length - 1) return null;
    return timeline[index + 1];
  }

  bool get isActive => this != delivered && this != cancelled;

  /// Customers may cancel until the kitchen starts. The server enforces the
  /// same rule; this only decides whether to offer the button.
  bool get customerCanCancel => this == pendingPayment || this == received;
}
