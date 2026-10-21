/// A bookable delivery window.
class DeliverySlot {
  const DeliverySlot({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  @override
  bool operator ==(Object other) =>
      other is DeliverySlot && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// All bookable slots of one calendar day.
class DeliveryDay {
  const DeliveryDay({required this.date, required this.slots});

  /// Midnight of the day.
  final DateTime date;
  final List<DeliverySlot> slots;
}
