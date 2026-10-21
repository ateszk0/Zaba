import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/checkout_steps.dart';
import 'support/pump_zaba.dart';

// The release build clips a row that does not fit without a word; a test
// reports it as an error. So walking the customer's whole path on the screens
// people really hold finds what would be cut off on their phones: a small
// phone, a phone on its side, and a system font turned up.

const _screens = {
  'a small phone (320 x 568)': (Size(320, 568), 1.0),
  'a small phone with a larger font': (Size(320, 568), 1.3),
  'a phone on its side (844 x 390)': (Size(844, 390), 1.0),
  'a phone with the largest Android font': (Size(390, 844), 2.0),
};

/// Scrolls until [finder] is on the screen, like a person looking for it. Lists
/// build lazily, so it moves the main list down a screenful at a time until the
/// thing has been built (moving the scroll position, not dragging: on a short
/// screen a drag may start on a widget that takes it).
Future<void> reveal(WidgetTester tester, Finder finder) async {
  final lists = find.byWidgetPredicate(
    (w) => w is Scrollable && w.axis == Axis.vertical,
  );
  // `find...first` throws, rather than being empty, when nothing is built yet.
  bool built() {
    try {
      return finder.evaluate().isNotEmpty;
    } on StateError {
      return false;
    }
  }

  while (!built()) {
    final list = tester.state<ScrollableState>(lists.first).position;
    if (list.pixels >= list.maxScrollExtent) {
      break;
    }
    list.jumpTo(list.pixels + list.viewportDimension / 2);
    await tester.pump();
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> tapRevealed(WidgetTester tester, Finder finder) async {
  await reveal(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> enterRevealed(
  WidgetTester tester,
  String label,
  String text,
) async {
  final field = find.widgetWithText(TextFormField, label);
  await reveal(tester, field);
  await tester.enterText(field, text);
}

void main() {
  for (final MapEntry(key: name, value: (screen, textScale))
      in _screens.entries) {
    group('on $name', () {
      testWidgets('the order, the card step and the tracking fit', (
        tester,
      ) async {
        await pumpZaba(tester, screen: screen, textScale: textScale);
        await enterAddress(tester);
        await tapRevealed(tester, find.byTooltip('Hozzáadás').first);
        await tapRevealed(tester, find.byTooltip('Több').first);
        await tapRevealed(tester, find.textContaining('Kosár megtekintése'));
        await tapRevealed(
          tester,
          find.widgetWithText(FilledButton, 'Tovább a fizetéshez · $total'),
        );

        await reveal(tester, find.text('2 × Spagetti carbonara'));
        await tapRevealed(
          tester,
          find.widgetWithText(FilledButton, 'Rendelés leadása · $total'),
        );
        expect(find.text('Fizetendő'), findsOneWidget);

        await enterRevealed(tester, 'Kártyaszám', '4242424242424242');
        await enterRevealed(tester, 'Lejárat (HH/ÉÉ)', '1228');
        await enterRevealed(tester, 'Biztonsági kód', '123');
        await enterRevealed(tester, 'Név a kártyán', 'Teszt Elek');
        await tapRevealed(
          tester,
          find.widgetWithText(FilledButton, 'Fizetés · $total'),
        );

        expect(find.text('Rendelés ZB-1001'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the menu, the product sheet, the cart and the profile fit', (
        tester,
      ) async {
        await pumpZaba(tester, screen: screen, textScale: textScale);

        await tapRevealed(tester, find.text('Spagetti carbonara').first);
        await reveal(tester, find.text('Allergének'));
        // On a small screen the sheet covers almost everything, so there is no
        // backdrop to tap: close it with the back gesture.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        await tester.tap(navTab('Kosár'));
        await tester.pumpAndSettle();
        await tester.tap(navTab('Rendeléseim'));
        await tester.pumpAndSettle();
        await tester.tap(navTab('Profil'));
        await tester.pumpAndSettle();
        await reveal(tester, find.text('Ez egy demó'));
        expect(tester.takeException(), isNull);
      });

      testWidgets('the sign-in and registration forms fit', (tester) async {
        await pumpZaba(
          tester,
          signedIn: false,
          screen: screen,
          textScale: textScale,
        );
        await tester.tap(navTab('Profil'));
        await tester.pumpAndSettle();

        await tapRevealed(tester, find.widgetWithText(FilledButton, 'Belépés'));
        // Empty fields: the error texts make the form taller.
        await tapRevealed(tester, find.widgetWithText(FilledButton, 'Belépés'));
        await reveal(tester, find.text('Add meg az e-mail-címet.'));

        await tapRevealed(tester, find.text('Még nincs fiókod? Regisztrálj'));
        await tapRevealed(
          tester,
          find.widgetWithText(FilledButton, 'Fiók létrehozása'),
        );
        await reveal(tester, find.text('Add meg az e-mail-címet.'));
        expect(tester.takeException(), isNull);
      });
    });
  }
}
