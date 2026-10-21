import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/delivery_slot.dart';
import '../domain/delivery_slot_service.dart';

/// The delivery slots from Supabase (`get_delivery_slots`, signed-in customers
/// only). The server lays the slots out in the shop's time zone, applies the
/// opening hours, the lead time and the capacity, using its own clock: the `now`
/// the interface passes in is not used.
///
/// Days and times are shown in the device's time zone; in Hungary that is the
/// shop's.
class SupabaseDeliverySlotService implements DeliverySlotService {
  SupabaseDeliverySlotService(this._client);

  final SupabaseClient _client;

  @override
  Future<List<DeliveryDay>> availableDays({required DateTime now}) async {
    final rows = await _client.rpc('get_delivery_slots') as List<dynamic>;
    return deliveryDaysFromRows(rows.cast<Map<String, dynamic>>());
  }

  /// Asks the server again, so the answer is as fresh as it gets.
  @override
  Future<bool> isAvailable(DeliverySlot slot, {required DateTime now}) async {
    final days = await availableDays(now: now);
    return days.any((day) => day.slots.any((open) => open.id == slot.id));
  }
}

/// Groups the server's slots into calendar days (earliest first).
List<DeliveryDay> deliveryDaysFromRows(List<Map<String, dynamic>> rows) {
  final slots = [
    for (final row in rows)
      DeliverySlot(
        id: row['slot_id'] as String,
        start: DateTime.parse(row['starts_at'] as String).toLocal(),
        end: DateTime.parse(row['ends_at'] as String).toLocal(),
      ),
  ]..sort((a, b) => a.start.compareTo(b.start));

  final byDay = <DateTime, List<DeliverySlot>>{};
  for (final slot in slots) {
    final date = DateTime(slot.start.year, slot.start.month, slot.start.day);
    (byDay[date] ??= []).add(slot);
  }
  return [
    for (final MapEntry(key: date, value: daySlots) in byDay.entries)
      DeliveryDay(date: date, slots: daySlots),
  ];
}
