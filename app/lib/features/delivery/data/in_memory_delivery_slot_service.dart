import '../domain/delivery_slot.dart';
import '../domain/delivery_slot_service.dart';

/// Hourly slots over the opening hours: Monday to Saturday 11:00-21:00,
/// Sunday 11:00-20:00. Times are device-local; the real service generates
/// slots in Europe/Budapest on the server (daylight saving time included).
class InMemoryDeliverySlotService implements DeliverySlotService {
  const InMemoryDeliverySlotService({
    this.leadTime = const Duration(minutes: 45),
    this.days = 3,
  });

  /// How long before its start a slot stops being bookable.
  final Duration leadTime;

  /// How many calendar days (today included) can be booked.
  final int days;

  static const _openingHour = 11;

  int _closingHour(DateTime date) => date.weekday == DateTime.sunday ? 20 : 21;

  @override
  Future<List<DeliveryDay>> availableDays({required DateTime now}) async {
    final earliest = now.add(leadTime);
    final result = <DeliveryDay>[];
    for (var offset = 0; offset < days; offset++) {
      final date = DateTime(now.year, now.month, now.day + offset);
      final slots = [
        for (var hour = _openingHour; hour < _closingHour(date); hour++)
          DeliverySlot(
            start: DateTime(date.year, date.month, date.day, hour),
            end: DateTime(date.year, date.month, date.day, hour + 1),
          ),
      ].where((slot) => !slot.start.isBefore(earliest)).toList();
      if (slots.isNotEmpty) result.add(DeliveryDay(date: date, slots: slots));
    }
    return result;
  }

  @override
  Future<bool> isAvailable(DeliverySlot slot, {required DateTime now}) async {
    final available = await availableDays(now: now);
    return available.any((day) => day.slots.contains(slot));
  }
}
