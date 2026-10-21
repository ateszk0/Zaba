import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/features/delivery/data/in_memory_delivery_slot_service.dart';
import 'package:zaba/features/delivery/domain/delivery_slot.dart';

void main() {
  const service = InMemoryDeliverySlotService();

  // 2026-10-21 is a Wednesday, 2026-10-25 a Sunday.
  List<int> startHours(DeliveryDay day) => [
    for (final slot in day.slots) slot.start.hour,
  ];

  test(
    'offers hourly slots from 11 to 21 on a weekday, three days ahead',
    () async {
      final days = await service.availableDays(now: DateTime(2026, 10, 21, 8));

      expect(days.map((day) => day.date.day), [21, 22, 23]);
      expect(startHours(days.first), [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]);
      expect(days.first.slots.first.end, DateTime(2026, 10, 21, 12));
    },
  );

  test('a slot stops being bookable 45 minutes before it starts', () async {
    // 11:15 + 45 min = 12:00, so 12:00 is still bookable and 11:00 is not.
    final days = await service.availableDays(
      now: DateTime(2026, 10, 21, 11, 15),
    );
    expect(startHours(days.first).first, 12);

    // One minute later the 12:00 slot is gone too.
    final later = await service.availableDays(
      now: DateTime(2026, 10, 21, 11, 16),
    );
    expect(startHours(later.first).first, 13);
  });

  test(
    'a day with no slots left is omitted; the horizon stays today + 2',
    () async {
      final days = await service.availableDays(
        now: DateTime(2026, 10, 21, 20, 30),
      );

      expect(days.map((day) => day.date.day), [22, 23]);
    },
  );

  test('the last slot is one hour earlier on Sunday', () async {
    final days = await service.availableDays(now: DateTime(2026, 10, 25, 8));

    expect(startHours(days.first).last, 19);
  });

  test('isAvailable reflects the current slots', () async {
    final now = DateTime(2026, 10, 21, 8);
    final open = DeliverySlot(
      id: 'open',
      start: DateTime(2026, 10, 21, 12),
      end: DateTime(2026, 10, 21, 13),
    );
    final tooEarly = DeliverySlot(
      id: 'too-early',
      start: DateTime(2026, 10, 21, 8),
      end: DateTime(2026, 10, 21, 9),
    );
    final odd = DeliverySlot(
      id: 'odd',
      start: DateTime(2026, 10, 21, 12, 30),
      end: DateTime(2026, 10, 21, 13, 30),
    );

    expect(await service.isAvailable(open, now: now), isTrue);
    expect(await service.isAvailable(tooEarly, now: now), isFalse);
    expect(await service.isAvailable(odd, now: now), isFalse);
    expect(
      await service.isAvailable(open, now: DateTime(2026, 10, 21, 12)),
      isFalse,
    );
  });
}
