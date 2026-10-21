import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/core/money/money.dart';

import 'pump_zaba.dart';

/// The usual walk to the checkout and through the card step, shared by the
/// flow tests.

String forint(int amount) => Money(amount).format();

/// 2 carbonaras (5 580 Ft) + 990 Ft delivery to district V.
final total = forint(2 * 2790 + 990);

/// Address, two carbonaras, cart, checkout.
Future<void> reachCheckout(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  await pumpZaba(tester, overrides: overrides);
  await enterAddress(tester);
  await tester.tap(find.byTooltip('Hozzáadás').first);
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Több').first);
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('Kosár megtekintése'));
  await tester.pumpAndSettle();
  await tester.tap(
    find.widgetWithText(FilledButton, 'Tovább a fizetéshez · $total'),
  );
  await tester.pumpAndSettle();
}

Future<void> placeOrder(WidgetTester tester) async {
  await tester.tap(
    find.widgetWithText(FilledButton, 'Rendelés leadása · $total'),
  );
  await tester.pumpAndSettle();
}

Future<void> fillCard(
  WidgetTester tester, {
  String number = '4242424242424242',
}) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Kártyaszám'),
    number,
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Lejárat (HH/ÉÉ)'),
    '1228',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Biztonsági kód'),
    '123',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Név a kártyán'),
    'Teszt Elek',
  );
}

Future<void> pay(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Fizetés · $total'));
  await tester.pumpAndSettle();
}
