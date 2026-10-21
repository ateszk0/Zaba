import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/core/money/money.dart';
import 'package:zaba/core/widgets/quantity_stepper.dart';

import '../../support/pump_zaba.dart';

// The price is on the left of a product card and its button on the right. A layout that
// only avoids overflowing (the small-screen test) would pass with the button sitting next
// to the price; this one does not.

Rect cardOf(WidgetTester tester, Finder inside) => tester.getRect(
  find.ancestor(of: inside, matching: find.byType(Card)).first,
);

void main() {
  testWidgets(
    'the add button is at the right edge of its card, the price on the left',
    (tester) async {
      await pumpZaba(tester);

      final button = find.byTooltip('Hozzáadás').first;
      final card = cardOf(tester, button);

      // The card's own padding is 12; allow a little more for its border.
      expect(
        card.right - tester.getRect(button).right,
        inInclusiveRange(0, 16),
      );
      final price = tester.getRect(
        find.descendant(
          of: find.ancestor(of: button, matching: find.byType(Card)).first,
          matching: find.text(const Money(2790).format()),
        ),
      );
      expect(price.left - card.left, lessThan(120));
      expect(tester.getRect(button).left - price.right, greaterThan(40));
    },
  );

  testWidgets(
    'the quantity stepper takes the button\'s place at the right edge',
    (tester) async {
      await pumpZaba(tester);
      await tester.tap(find.byTooltip('Hozzáadás').first);
      await tester.pumpAndSettle();

      final stepper = find.byType(QuantityStepper).first;
      final card = cardOf(tester, stepper);

      expect(
        card.right - tester.getRect(stepper).right,
        inInclusiveRange(0, 16),
      );
    },
  );
}
