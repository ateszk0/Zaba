/// A bookable delivery window. [id] is what an order books; on the server it
/// is the id of the slot row.
class DeliverySlot {
  const DeliverySlot({
    required this.id,
    required this.start,
    required this.end,
  });

  final String id;
  final DateTime start;
  final DateTime end;

  @override
  bool operator ==(Object other) =>
      other is DeliverySlot &&
      other.id == id &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(id, start, end);
}

/// All bookable slots of one calendar day.
class DeliveryDay {
  const DeliveryDay({required this.date, required this.slots});

  /// Midnight of the day.
  final DateTime date;
  final List<DeliverySlot> slots;
}
