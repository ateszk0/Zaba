import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock.dart';
import '../data/in_memory_delivery_slot_service.dart';
import '../data/in_memory_delivery_zone_repository.dart';
import '../domain/delivery_address.dart';
import '../domain/delivery_slot.dart';
import '../domain/delivery_slot_service.dart';
import '../domain/delivery_zone.dart';
import '../domain/delivery_zone_repository.dart';

final deliverySlotServiceProvider = Provider<DeliverySlotService>(
  (ref) => const InMemoryDeliverySlotService(),
);

/// The days that can still be booked, with their slots.
final deliveryDaysProvider = FutureProvider<List<DeliveryDay>>(
  (ref) => ref
      .watch(deliverySlotServiceProvider)
      .availableDays(now: ref.watch(clockProvider)()),
);

final deliveryZoneRepositoryProvider = Provider<DeliveryZoneRepository>(
  (ref) => const InMemoryDeliveryZoneRepository(),
);

/// The customer's chosen delivery address; null until they enter one.
class DeliveryAddressNotifier extends Notifier<DeliveryAddress?> {
  @override
  DeliveryAddress? build() => null;

  void set(DeliveryAddress address) => state = address;
}

final deliveryAddressProvider =
    NotifierProvider<DeliveryAddressNotifier, DeliveryAddress?>(
      DeliveryAddressNotifier.new,
    );

/// The zone of the chosen address, or the default zone before there is one.
final deliveryZoneProvider = FutureProvider<DeliveryZone>((ref) async {
  final zones = ref.watch(deliveryZoneRepositoryProvider);
  final address = ref.watch(deliveryAddressProvider);
  if (address == null) return zones.defaultZone();
  return await zones.zoneForPostalCode(address.postalCode) ??
      await zones.defaultZone();
});
