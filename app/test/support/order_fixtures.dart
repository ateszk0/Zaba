import 'package:zaba/core/money/money.dart';
import 'package:zaba/features/cart/data/in_memory_quote_service.dart';
import 'package:zaba/features/catalog/data/in_memory_catalog_repository.dart';
import 'package:zaba/features/delivery/data/in_memory_delivery_slot_service.dart';
import 'package:zaba/features/delivery/data/in_memory_delivery_zone_repository.dart';
import 'package:zaba/features/delivery/domain/delivery_address.dart';
import 'package:zaba/features/delivery/domain/delivery_slot.dart';
import 'package:zaba/features/orders/data/in_memory_order_store.dart';
import 'package:zaba/features/orders/domain/order.dart';
import 'package:zaba/features/orders/domain/order_repository.dart';
import 'package:zaba/features/orders/domain/order_status.dart';

import 'test_catalog.dart';

/// "Now" for order tests: a Wednesday at 10:00.
final fixedNow = DateTime(2026, 10, 21, 10);

/// A slot that is bookable at [fixedNow].
final bookableSlot = DeliverySlot(
  id: 'bookable',
  start: DateTime(2026, 10, 21, 12),
  end: DateTime(2026, 10, 21, 13),
);

const innerAddress = DeliveryAddress(
  postalCode: '1051',
  street: 'Váci utca 12.',
);
const outsideAddress = DeliveryAddress(
  postalCode: '1181',
  street: 'Teszt utca 1.',
);

InMemoryOrderStore newOrderStore({DateTime Function()? clock}) =>
    InMemoryOrderStore(
      quoteService: const InMemoryQuoteService(
        catalog: InMemoryCatalogRepository(
          categoryList: testCategories,
          productList: testProducts,
        ),
        zones: InMemoryDeliveryZoneRepository(),
      ),
      slotService: const InMemoryDeliverySlotService(),
      clock: clock ?? () => fixedNow,
    );

/// Two carbonaras: 5 580 Ft, above the 3 500 Ft minimum of the inner zone.
PlaceOrderRequest validRequest({String key = 'key-1'}) => PlaceOrderRequest(
  idempotencyKey: key,
  lines: const {'carbonara': 2},
  address: innerAddress,
  slot: bookableSlot,
  note: '  csengő nem működik  ',
);

/// An order as the server would return it, for tests that only need one to exist.
Order sampleOrder({OrderStatus status = OrderStatus.received}) => Order(
  id: 'order-1',
  number: 'ZB-1001',
  placedAt: fixedNow,
  lines: const [
    OrderLine(
      productId: 'carbonara',
      name: 'Spagetti carbonara',
      quantity: 2,
      unitPrice: Money(2790),
    ),
  ],
  subtotal: const Money(5580),
  deliveryFee: const Money(990),
  address: innerAddress,
  slot: bookableSlot,
  note: '',
  status: status,
  paymentStatus: PaymentStatus.succeeded,
);
