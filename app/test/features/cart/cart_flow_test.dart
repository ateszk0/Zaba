import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/core/money/money.dart';
import 'package:zaba/features/cart/application/cart_providers.dart';
import 'package:zaba/features/cart/domain/cart_quote.dart';
import 'package:zaba/features/cart/domain/cart_store.dart';
import 'package:zaba/features/cart/domain/quote_service.dart';
import 'package:zaba/features/catalog/domain/product.dart';

import '../../support/pump_zaba.dart';
import '../../support/test_catalog.dart';

String forint(int amount) => Money(amount).format();

/// Answers with whatever [answer] returns and counts the questions.
class ScriptedQuoteService implements QuoteService {
  ScriptedQuoteService(this.answer);

  final Future<CartQuote> Function(Map<String, int> lines) answer;
  var calls = 0;

  @override
  Future<CartQuote> quote({
    required Map<String, int> lines,
    String? postalCode,
  }) {
    calls++;
    return answer(lines);
  }
}

CartQuote quoteOf(List<QuoteLine> lines, {Money delivery = const Money(990)}) {
  final subtotal = Money.sum(lines.map((line) => line.total));
  return CartQuote(
    lines: lines,
    subtotal: subtotal,
    deliveryFee: delivery,
    minOrder: const Money(3500),
    estimated: true,
  );
}

QuoteLine lineOf(Product product, {required int quantity, required int unit}) =>
    QuoteLine(
      product: product,
      quantity: quantity,
      unitPrice: Money(unit),
      total: Money(unit * quantity),
    );

void main() {
  testWidgets('a saved cart is there when the app opens', (tester) async {
    final store = MemoryCartStore({'carbonara': 2, 'lemonade': 1});
    await pumpZaba(
      tester,
      overrides: [cartStoreProvider.overrideWithValue(store)],
    );

    expect(find.text('Kosár megtekintése · 3 tétel'), findsOneWidget);

    await tester.tap(navTab('Kosár'));
    await tester.pumpAndSettle();
    expect(find.text('Spagetti carbonara'), findsOneWidget);
    expect(find.text('Házi limonádé'), findsOneWidget);
    expect(find.text(forint(2 * 2790)), findsOneWidget);
  });

  testWidgets('a product that is no longer sold drops out of the cart', (
    tester,
  ) async {
    final store = MemoryCartStore({'carbonara': 2, 'ghost': 1});
    await pumpZaba(
      tester,
      overrides: [cartStoreProvider.overrideWithValue(store)],
    );

    expect(find.text('Kosár megtekintése · 2 tétel'), findsOneWidget);
    expect(store.load(), {'carbonara': 2});
  });

  testWidgets('what is added is saved at once', (tester) async {
    final store = MemoryCartStore();
    await pumpZaba(
      tester,
      overrides: [cartStoreProvider.overrideWithValue(store)],
    );

    await tester.tap(find.byTooltip('Hozzáadás').first);
    await tester.pumpAndSettle();

    expect(store.load(), {'carbonara': 1});
  });

  testWidgets('the cart shows the quote\'s prices, not the menu\'s', (
    tester,
  ) async {
    // The server says the carbonara costs 2 990 now; the menu still has 2 790.
    final quotes = ScriptedQuoteService(
      (lines) async => quoteOf([lineOf(carbonara, quantity: 2, unit: 2990)]),
    );
    await pumpZaba(
      tester,
      overrides: [
        cartStoreProvider.overrideWithValue(MemoryCartStore({'carbonara': 2})),
        quoteServiceProvider.overrideWithValue(quotes),
      ],
    );

    await tester.tap(navTab('Kosár'));
    await tester.pumpAndSettle();

    expect(find.text(forint(2 * 2990)), findsWidgets);
    expect(find.text(forint(2 * 2790)), findsNothing);
  });

  testWidgets('an empty cart is not sent to the server', (tester) async {
    final quotes = ScriptedQuoteService(
      (lines) async => quoteOf([lineOf(carbonara, quantity: 1, unit: 2790)]),
    );
    await pumpZaba(
      tester,
      overrides: [quoteServiceProvider.overrideWithValue(quotes)],
    );

    await tester.tap(navTab('Kosár'));
    await tester.pumpAndSettle();

    expect(find.text('Üres a kosarad'), findsOneWidget);
    expect(quotes.calls, 0);
  });

  testWidgets('when pricing fails the cart says so and Újra recovers', (
    tester,
  ) async {
    var serverUp = false;
    final quotes = ScriptedQuoteService((lines) async {
      if (!serverUp) {
        throw Exception('offline');
      }
      return quoteOf([lineOf(carbonara, quantity: 2, unit: 2790)]);
    });
    await pumpZaba(
      tester,
      overrides: [
        cartStoreProvider.overrideWithValue(MemoryCartStore({'carbonara': 2})),
        quoteServiceProvider.overrideWithValue(quotes),
      ],
    );

    await tester.tap(navTab('Kosár'));
    await tester.pumpAndSettle();
    expect(find.text('Hoppá, valami elromlott'), findsOneWidget);
    // The saved cart is not thrown away because the server was unreachable.
    expect(find.byType(Badge), findsWidgets);

    serverUp = true;
    await tester.tap(find.text('Újra'));
    await tester.pumpAndSettle();

    expect(find.text('Hoppá, valami elromlott'), findsNothing);
    expect(find.text('Spagetti carbonara'), findsOneWidget);
  });
}
