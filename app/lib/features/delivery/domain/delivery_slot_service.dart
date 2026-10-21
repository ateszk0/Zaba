import 'delivery_slot.dart';

abstract interface class DeliverySlotService {
  /// The days that still have bookable slots at [now], earliest first.
  Future<List<DeliveryDay>> availableDays({required DateTime now});

  /// Whether [slot] can still be booked at [now].
  Future<bool> isAvailable(DeliverySlot slot, {required DateTime now});
}
