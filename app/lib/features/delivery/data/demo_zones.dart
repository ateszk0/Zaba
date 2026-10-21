import '../../../core/money/money.dart';
import '../domain/delivery_zone.dart';

// Demo terms; the real values are configured by the operator.

const innerZone = DeliveryZone(
  id: 'inner',
  name: 'Belső kerületek',
  // Districts I, II, V-IX, XI-XIII.
  postalPrefixes: {
    '101',
    '102',
    '105',
    '106',
    '107',
    '108',
    '109',
    '111',
    '112',
    '113',
  },
  deliveryFee: Money(990),
  minOrder: Money(3500),
  freeDeliveryFrom: Money(15000),
  etaMinMinutes: 35,
  etaMaxMinutes: 50,
);

const outerZone = DeliveryZone(
  id: 'outer',
  name: 'Külső kerületek',
  // Districts III, IV, X, XIV-XVI.
  postalPrefixes: {'103', '104', '110', '114', '115', '116'},
  deliveryFee: Money(1490),
  minOrder: Money(5000),
  etaMinMinutes: 45,
  etaMaxMinutes: 60,
);

const demoZones = [innerZone, outerZone];
