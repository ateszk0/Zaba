import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/features/delivery/application/delivery_providers.dart';
import 'package:zaba/features/delivery/data/demo_zones.dart';
import 'package:zaba/features/delivery/domain/delivery_zone.dart';
import 'package:zaba/features/delivery/domain/delivery_zone_repository.dart';

import '../../support/pump_zaba.dart';

/// Zones that can be shown by default, but whose lookup fails (no network).
class _UnreachableZones implements DeliveryZoneRepository {
  @override
  Future<DeliveryZone?> zoneForPostalCode(String postalCode) async =>
      throw StateError('no network');

  @override
  Future<DeliveryZone> defaultZone() async => innerZone;
}

void main() {
  testWidgets('a failed zone lookup is said out loud, and nothing is saved', (
    tester,
  ) async {
    await pumpZaba(
      tester,
      overrides: [
        deliveryZoneRepositoryProvider.overrideWithValue(_UnreachableZones()),
      ],
    );
    await tester.tap(find.text('Add meg a címed'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Irányítószám'),
      '1051',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Utca, házszám'),
      'Váci utca 12.',
    );

    await tester.tap(find.text('Mentés'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text(
        'Most nem sikerült ellenőrizni az irányítószámot. Próbáld újra.',
      ),
      findsOneWidget,
    );
    // The dialog is still open, so the customer can try again.
    expect(find.widgetWithText(TextField, 'Irányítószám'), findsOneWidget);
  });
}
