import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/core/money/money.dart';

import '../support/pump_zaba.dart';

String forint(int amount) => Money(amount).format();

/// 2 carbonaras (5 580 Ft) + 990 Ft delivery to district V.
final total = forint(2 * 2790 + 990);

Future<void> enterAddress(WidgetTester tester) async {
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
}

/// Address, two carbonaras, cart, checkout.
Future<void> reachCheckout(WidgetTester tester) async {
  await pumpZaba(tester);
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

void main() {
  testWidgets('checkout shows address, the first free slot and the summary', (
    tester,
  ) async {
    await reachCheckout(tester);

    expect(find.text('1051 Budapest, Váci utca 12.'), findsOneWidget);
    // 10:00 now, 45 minutes of lead time: the 11:00 slot of today is the first.
    expect(find.widgetWithText(ChoiceChip, 'Ma'), findsOneWidget);
    final firstSlot = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '11:00–12:00'),
    );
    expect(firstSlot.selected, isTrue);
    await scrollListTo(tester, find.text('2 × Spagetti carbonara'));
    expect(find.text('2 × Spagetti carbonara'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Rendelés leadása · $total'),
      findsOneWidget,
    );
  });

  testWidgets('another day and slot can be chosen', (tester) async {
    await reachCheckout(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Holnap'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '15:00–16:00'));
    await tester.pumpAndSettle();

    final chosen = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '15:00–16:00'),
    );
    expect(chosen.selected, isTrue);

    await placeOrder(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Mégse'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2026. 10. 22. 15:00–16:00'), findsWidgets);
  });

  testWidgets(
    'placing an order empties the cart and opens the payment screen',
    (tester) async {
      await reachCheckout(tester);

      await placeOrder(tester);

      expect(find.text('Fizetendő'), findsOneWidget);
      expect(find.text('Rendelés: ZB-1001'), findsOneWidget);
      expect(find.text('Demó teszt kártyák'), findsOneWidget);
      // The cart is empty: no badge on the cart tab.
      expect(find.byType(Badge), findsNothing);
    },
  );

  testWidgets('a successful card payment leads to the live order tracking', (
    tester,
  ) async {
    await reachCheckout(tester);
    await placeOrder(tester);
    await fillCard(tester);

    await pay(tester);

    expect(find.text('Rendelés ZB-1001'), findsOneWidget);
    expect(find.text('Rendelés fogadva'), findsWidgets);
    expect(find.text('Kifizetve'), findsOneWidget);

    // The operator moves the order forward; the screen follows.
    await tester.tap(find.text('Következő állapot (demó)'));
    await tester.pumpAndSettle();
    expect(find.text('Készül'), findsWidgets);
    // Once the kitchen has started, the customer cannot cancel any more.
    expect(find.text('Rendelés lemondása'), findsNothing);
  });

  testWidgets('a declined card shows an error and a retry can succeed', (
    tester,
  ) async {
    await reachCheckout(tester);
    await placeOrder(tester);

    await fillCard(tester, number: '4000000000000002');
    await pay(tester);
    expect(
      find.text('A kártyádat elutasították. Próbálj meg másik kártyát.'),
      findsOneWidget,
    );
    expect(find.text('Fizetendő'), findsOneWidget);

    await fillCard(tester);
    await pay(tester);
    expect(find.text('Rendelés ZB-1001'), findsOneWidget);
    expect(find.text('Kifizetve'), findsOneWidget);
  });

  testWidgets('an incomplete card form is validated before anything is sent', (
    tester,
  ) async {
    await reachCheckout(tester);
    await placeOrder(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Fizetés · $total'));
    await tester.pumpAndSettle();

    expect(find.text('Érvénytelen kártyaszám.'), findsOneWidget);
    expect(find.text('Érvénytelen lejárati dátum.'), findsOneWidget);
    expect(find.text('3 jegyű biztonsági kód kell.'), findsOneWidget);
    expect(find.text('Add meg a kártyabirtokos nevét.'), findsOneWidget);
    expect(find.text('Fizetendő'), findsOneWidget);
  });

  testWidgets(
    'cancelling the card step leaves an unpaid order that can be paid later',
    (tester) async {
      await reachCheckout(tester);
      await placeOrder(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Mégse'));
      await tester.pumpAndSettle();

      expect(find.text('Rendelés ZB-1001'), findsOneWidget);
      expect(find.text('Fizetésre vár'), findsWidgets);
      expect(find.text('A rendelés még nem fizetett'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Fizetés · $total'));
      await tester.pumpAndSettle();
      expect(find.text('Fizetendő'), findsOneWidget);
      await fillCard(tester);
      await pay(tester);
      expect(find.text('Rendelés fogadva'), findsWidgets);
    },
  );

  testWidgets('an unpaid order can be cancelled', (tester) async {
    await reachCheckout(tester);
    await placeOrder(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Mégse'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rendelés lemondása'));
    await tester.pumpAndSettle();
    expect(find.text('Lemondod a rendelést?'), findsOneWidget);
    await tester.tap(find.text('Lemondom'));
    await tester.pumpAndSettle();

    expect(find.text('Lemondva'), findsWidgets);
    expect(find.text('Rendelés lemondása'), findsNothing);
  });

  testWidgets('a paid order can be cancelled and is refunded', (tester) async {
    await reachCheckout(tester);
    await placeOrder(tester);
    await fillCard(tester);
    await pay(tester);

    await tester.tap(find.text('Rendelés lemondása'));
    await tester.pumpAndSettle();
    expect(find.text('A kifizetett összeget visszatérítjük.'), findsOneWidget);
    await tester.tap(find.text('Lemondom'));
    await tester.pumpAndSettle();

    expect(find.text('Lemondva'), findsWidgets);
    expect(find.text('Visszatérítve'), findsOneWidget);
  });

  testWidgets('the orders tab lists the order with its status', (tester) async {
    await reachCheckout(tester);
    await placeOrder(tester);
    await fillCard(tester);
    await pay(tester);

    // Tapping the selected tab again goes back to the list of orders.
    await tester.tap(navTab('Rendeléseim'));
    await tester.pumpAndSettle();

    expect(find.text('ZB-1001'), findsOneWidget);
    expect(find.text('Rendelés fogadva'), findsOneWidget);
    expect(find.text(total), findsOneWidget);

    await tester.tap(find.text('ZB-1001'));
    await tester.pumpAndSettle();
    expect(find.text('Rendelés ZB-1001'), findsOneWidget);
  });

  testWidgets('without an address the order cannot be placed', (tester) async {
    await pumpZaba(tester);
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

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Rendelés leadása · $total'),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Add meg a szállítási címet'), findsOneWidget);
  });
}
