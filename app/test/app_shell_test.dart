import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/app.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    // A typical phone: 390 x 844 logical pixels.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: ZabaApp()));
    await tester.pumpAndSettle();
  }

  Finder tab(String label) => find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );

  testWidgets('shows the four tabs', (tester) async {
    await pumpApp(tester);

    expect(find.textContaining('DEMÓ'), findsNothing);
    for (final label in ['Étlap', 'Kosár', 'Rendeléseim', 'Profil']) {
      expect(tab(label), findsOneWidget);
    }
    // Starts on the menu tab with the demo catalog loaded.
    expect(find.text('Szállítás ide'), findsOneWidget);
    expect(find.text('Étel keresése'), findsOneWidget);
  });

  testWidgets('switches between tabs', (tester) async {
    await pumpApp(tester);

    await tester.tap(tab('Kosár'));
    await tester.pumpAndSettle();
    expect(find.text('Üres a kosarad'), findsOneWidget);

    await tester.tap(tab('Rendeléseim'));
    await tester.pumpAndSettle();
    // A guest is asked to sign in instead (a signed-in customer sees the
    // empty list: see auth_flow_test.dart).
    expect(find.text('Lépj be a rendeléseidhez'), findsOneWidget);
  });

  testWidgets('profile explains the demo and opens the dev gallery', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(tab('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Ez egy demó'), findsOneWidget);

    await tester.tap(find.text('Komponens-galéria (fejlesztői)'));
    await tester.pumpAndSettle();
    expect(find.text('Árvíztűrő tükörfúrógép'), findsWidgets);

    // The gallery is a lazy list: scroll down to the price samples.
    final price = find.text('1\u00A0290\u00A0Ft');
    await tester.scrollUntilVisible(price, 300);
    expect(price, findsOneWidget);
  });
}
