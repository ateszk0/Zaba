import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/core/money/money.dart';
import 'package:zaba/features/auth/data/in_memory_auth_repository.dart';

import '../../support/pump_zaba.dart';

final total = Money(2 * 2790 + 990).format();

/// A guest with two carbonaras in the cart, standing at the cart's button.
Future<void> guestWithFilledCart(WidgetTester tester) async {
  await pumpZaba(tester, signedIn: false);
  await enterAddress(tester);
  await tester.tap(find.byTooltip('Hozzáadás').first);
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Több').first);
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('Kosár megtekintése'));
  await tester.pumpAndSettle();
}

Future<void> tapCheckoutButton(WidgetTester tester) async {
  await tester.tap(
    find.widgetWithText(FilledButton, 'Tovább a fizetéshez · $total'),
  );
  await tester.pumpAndSettle();
}

Finder field(String label) => find.widgetWithText(TextFormField, label);

Future<void> fillAndSubmit(
  WidgetTester tester, {
  required String email,
  required String password,
  required String action,
}) async {
  await tester.enterText(field('E-mail-cím'), email);
  await tester.enterText(field('Jelszó'), password);
  await tester.tap(find.widgetWithText(FilledButton, action));
  await tester.pumpAndSettle();
}

void main() {
  group('ordering needs an account', () {
    testWidgets('a guest at the checkout button is asked to sign in, and the '
        'demo account brings them straight back', (tester) async {
      await guestWithFilledCart(tester);

      await tapCheckoutButton(tester);
      expect(
        find.text('A rendelés leadásához be kell jelentkezned.'),
        findsOne,
      );

      await tester.tap(find.text('Belépés demó fiókkal'));
      await tester.pumpAndSettle();

      // Back where they were heading, with the cart intact.
      expect(
        find.widgetWithText(FilledButton, 'Rendelés leadása · $total'),
        findsOneWidget,
      );

      // The cart is still underneath: Back leads there, not out of the app.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(FilledButton, 'Tovább a fizetéshez · $total'),
        findsOneWidget,
      );
    });

    testWidgets('registering also returns to the checkout', (tester) async {
      await guestWithFilledCart(tester);
      await tapCheckoutButton(tester);

      await tester.tap(find.text('Még nincs fiókod? Regisztrálj'));
      await tester.pumpAndSettle();
      expect(find.text('Fiók létrehozása'), findsWidgets);

      await tester.enterText(field('Név (nem kötelező)'), 'Kovács Anna');
      await fillAndSubmit(
        tester,
        email: 'anna@example.com',
        password: 'hosszu-jelszo',
        action: 'Fiók létrehozása',
      );

      expect(
        find.widgetWithText(FilledButton, 'Rendelés leadása · $total'),
        findsOneWidget,
      );
    });

    testWidgets('the order list asks a guest to sign in', (tester) async {
      await pumpZaba(tester, signedIn: false);

      await tester.tap(navTab('Rendeléseim'));
      await tester.pumpAndSettle();
      expect(find.text('Lépj be a rendeléseidhez'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Belépés'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Belépés demó fiókkal'));
      await tester.pumpAndSettle();

      // Back on the (empty) order list of the signed-in customer.
      expect(find.text('Még nincs rendelésed'), findsOneWidget);
    });
  });

  group('the sign-in form', () {
    Future<void> openLogin(WidgetTester tester) async {
      await pumpZaba(tester, signedIn: false);
      await tester.tap(navTab('Profil'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Belépés'));
      await tester.pumpAndSettle();
    }

    testWidgets('checks the fields before anything is sent', (tester) async {
      await openLogin(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Belépés'));
      await tester.pumpAndSettle();
      expect(find.text('Add meg az e-mail-címet.'), findsOneWidget);
      expect(find.text('Add meg a jelszót.'), findsOneWidget);

      await tester.enterText(field('E-mail-cím'), 'nem-cim');
      await tester.pumpAndSettle();
      expect(find.text('Ez nem tűnik érvényes e-mail-címnek.'), findsOneWidget);
    });

    testWidgets('a wrong password shows a plain message and stays put', (
      tester,
    ) async {
      await openLogin(tester);

      await fillAndSubmit(
        tester,
        email: 'demo@zaba.example',
        password: 'rossz-jelszo',
        action: 'Belépés',
      );

      expect(find.text('Hibás e-mail-cím vagy jelszó.'), findsOneWidget);
      expect(find.text('Belépés demó fiókkal'), findsOneWidget);
    });

    testWidgets('the password can be shown and hidden', (tester) async {
      await openLogin(tester);

      EditableText input() => tester.widget<EditableText>(
        find.descendant(
          of: field('Jelszó'),
          matching: find.byType(EditableText),
        ),
      );
      expect(input().obscureText, isTrue);

      await tester.tap(find.byTooltip('Jelszó megjelenítése'));
      await tester.pump();
      expect(input().obscureText, isFalse);
    });

    testWidgets('registration refuses a short password and a taken address', (
      tester,
    ) async {
      await openLogin(tester);
      await tester.tap(find.text('Még nincs fiókod? Regisztrálj'));
      await tester.pumpAndSettle();

      await fillAndSubmit(
        tester,
        email: 'uj@example.com',
        password: 'rovid',
        action: 'Fiók létrehozása',
      );
      expect(find.text('A jelszó legalább 8 karakter legyen.'), findsOneWidget);

      await fillAndSubmit(
        tester,
        email: 'demo@zaba.example',
        password: 'hosszu-jelszo',
        action: 'Fiók létrehozása',
      );
      expect(
        find.text('Ezzel az e-mail-címmel már van fiók. Próbálj belépni.'),
        findsOneWidget,
      );
    });
  });

  group('the account on the profile', () {
    testWidgets('shows who is signed in, and signing out returns to guest', (
      tester,
    ) async {
      await pumpZaba(tester);
      await tester.tap(navTab('Profil'));
      await tester.pumpAndSettle();

      expect(find.text('Demó Dóra'), findsOneWidget);
      expect(find.text('demo@zaba.example'), findsOneWidget);

      await tester.tap(find.text('Kijelentkezés'));
      await tester.pumpAndSettle();
      expect(find.text('Nem vagy bejelentkezve'), findsOneWidget);

      // The order list is closed again.
      await tester.tap(navTab('Rendeléseim'));
      await tester.pumpAndSettle();
      expect(find.text('Lépj be a rendeléseidhez'), findsOneWidget);
    });

    testWidgets('an account with neither a name nor an address still shows', (
      tester,
    ) async {
      await pumpZaba(
        tester,
        auth: InMemoryAuthRepository(
          accounts: [(email: '', password: 'x', fullName: null)],
          signedInAs: '',
        ),
      );
      await tester.tap(navTab('Profil'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('?'), findsOneWidget);
      expect(find.text('Kijelentkezés'), findsOneWidget);
    });
  });
}
