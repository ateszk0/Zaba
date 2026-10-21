import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/core/money/money.dart';

import '../support/pump_zaba.dart';

String forint(int amount) => Money(amount).format();

void main() {
  testWidgets('the menu lists products grouped by category', (tester) async {
    await pumpZaba(tester);

    // Delivery terms of the default zone, at the top of the menu.
    expect(find.text('35–50 perc'), findsOneWidget);
    expect(find.text('Szállítás ${forint(990)}'), findsOneWidget);
    expect(find.text('Spagetti carbonara'), findsOneWidget);
    // The first section header and its chip.
    expect(find.text('Tészták'), findsNWidgets(2));

    await scrollListTo(tester, find.text('Házi limonádé'));
    expect(find.text('Házi limonádé'), findsOneWidget);
    expect(find.text('Italok'), findsWidgets);
  });

  testWidgets(
    'adding a product shows the cart bar and the badge, the stepper keeps counting',
    (tester) async {
      await pumpZaba(tester);
      expect(find.textContaining('Kosár megtekintése'), findsNothing);

      await tester.tap(find.byTooltip('Hozzáadás').first);
      await tester.pumpAndSettle();

      expect(find.text('Kosár megtekintése · 1 tétel'), findsOneWidget);
      expect(find.text(forint(2790)), findsWidgets);
      expect(
        find.descendant(of: find.byType(Badge), matching: find.text('1')),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Több').first);
      await tester.pumpAndSettle();
      expect(find.text('Kosár megtekintése · 2 tétel'), findsOneWidget);

      await tester.tap(find.byTooltip('Kevesebb').first);
      await tester.tap(find.byTooltip('Kevesebb').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Kosár megtekintése'), findsNothing);
    },
  );

  testWidgets(
    'the cart blocks checkout below the minimum order and allows it above',
    (tester) async {
      await pumpZaba(tester);

      // The cheapest item (lemonade, 790) is far below the 3 500 minimum.
      await tapCategoryChip(tester, 'Italok');
      await tester.tap(find.byTooltip('Hozzáadás').first);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Kosár megtekintése'));
      await tester.pumpAndSettle();

      expect(find.text('Házi limonádé'), findsOneWidget);
      expect(
        find.text(
          'Még ${forint(3500 - 790)} hiányzik a minimális rendelési értékig (${forint(3500)}).',
        ),
        findsOneWidget,
      );
      final blocked = tester.widget<FilledButton>(
        find.widgetWithText(
          FilledButton,
          'Tovább a fizetéshez · ${forint(790 + 990)}',
        ),
      );
      expect(blocked.onPressed, isNull);

      // A carbonara on top gets the cart over the minimum.
      await tester.tap(navTab('Étlap'));
      await tester.pumpAndSettle();
      await tapCategoryChip(tester, 'Összes');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Hozzáadás').first);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Kosár megtekintése'));
      await tester.pumpAndSettle();

      const total = 790 + 2790 + 990;
      final enabled = tester.widget<FilledButton>(
        find.widgetWithText(
          FilledButton,
          'Tovább a fizetéshez · ${forint(total)}',
        ),
      );
      expect(enabled.onPressed, isNotNull);
      expect(find.textContaining('hiányzik a minimális'), findsNothing);

      await tester.tap(
        find.widgetWithText(
          FilledButton,
          'Tovább a fizetéshez · ${forint(total)}',
        ),
      );
      await tester.pumpAndSettle();
      // On to the checkout, which still asks for the delivery address.
      expect(find.text('Pénztár'), findsOneWidget);
      expect(find.text('Add meg a szállítási címet'), findsOneWidget);
    },
  );

  testWidgets('the cart can be emptied', (tester) async {
    await pumpZaba(tester);
    await tester.tap(find.byTooltip('Hozzáadás').first);
    await tester.pumpAndSettle();
    await tester.tap(navTab('Kosár'));
    await tester.pumpAndSettle();
    expect(find.text('Spagetti carbonara'), findsOneWidget);

    await tester.tap(find.text('Ürítés'));
    await tester.pumpAndSettle();

    expect(find.text('Üres a kosarad'), findsOneWidget);
    await tester.tap(find.text('Étlap megtekintése'));
    await tester.pumpAndSettle();
    expect(find.text('Étel keresése'), findsOneWidget);
  });

  testWidgets('search ignores accents; a failed search can be cleared', (
    tester,
  ) async {
    await pumpZaba(tester);

    await tester.enterText(find.byType(SearchBar), 'rantott');
    await tester.pumpAndSettle();
    expect(find.text('Rántott sajt'), findsOneWidget);
    expect(find.text('Spagetti carbonara'), findsNothing);

    await tester.enterText(find.byType(SearchBar), 'nincs ilyen étel');
    await tester.pumpAndSettle();
    expect(find.text('Nincs találat'), findsOneWidget);

    await tester.tap(find.text('Szűrők törlése'));
    await tester.pumpAndSettle();
    expect(find.text('Spagetti carbonara'), findsOneWidget);
    expect(find.text('Nincs találat'), findsNothing);
  });

  testWidgets('category and vegetarian filters narrow the menu', (
    tester,
  ) async {
    await pumpZaba(tester);

    await tapCategoryChip(tester, 'Italok');
    expect(find.text('Házi limonádé'), findsOneWidget);
    expect(find.text('Spagetti carbonara'), findsNothing);

    await tapCategoryChip(tester, 'Összes');
    await scrollChipRowToStart(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'Vegetáriánus'));
    await tester.pumpAndSettle();
    expect(find.text('Spagetti carbonara'), findsNothing);
    expect(find.text('Penne arrabbiata'), findsOneWidget);
    expect(find.text('Házi limonádé'), findsOneWidget);
  });

  testWidgets(
    'the product sheet shows allergens and adds the chosen quantity',
    (tester) async {
      await pumpZaba(tester);

      await tester.tap(find.text('Penne arrabbiata'));
      await tester.pumpAndSettle();
      expect(find.text('Allergének'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Glutén'), findsOneWidget);
      expect(find.text('Hozzáadás · ${forint(2390)}'), findsOneWidget);

      await tester.tap(find.byTooltip('Több'));
      await tester.pumpAndSettle();
      expect(find.text('Hozzáadás · ${forint(2 * 2390)}'), findsOneWidget);

      await tester.tap(find.text('Hozzáadás · ${forint(2 * 2390)}'));
      await tester.pumpAndSettle();
      expect(find.text('Kosár megtekintése · 2 tétel'), findsOneWidget);
    },
  );

  testWidgets(
    'the address dialog rejects addresses outside the delivery area',
    (tester) async {
      await pumpZaba(tester);

      await tester.tap(find.text('Add meg a címed'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Irányítószám'),
        '1181',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Utca, házszám'),
        'Teszt utca 1.',
      );
      await tester.tap(find.text('Mentés'));
      await tester.pumpAndSettle();
      expect(find.text('Erre a címre nem szállítunk.'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Irányítószám'),
        '1051',
      );
      await tester.tap(find.text('Mentés'));
      await tester.pumpAndSettle();

      expect(find.text('1051 Budapest, Teszt utca 1.'), findsOneWidget);
      expect(find.text('Add meg a címed'), findsNothing);
    },
  );
}
