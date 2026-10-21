import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/app.dart';
import 'package:zaba/core/clock/clock.dart';
import 'package:zaba/features/auth/application/auth_providers.dart';
import 'package:zaba/features/auth/data/in_memory_auth_repository.dart';
import 'package:zaba/features/payment/application/payment_providers.dart';
import 'package:zaba/features/catalog/application/catalog_providers.dart';
import 'package:zaba/features/catalog/data/in_memory_catalog_repository.dart';
import 'package:zaba/features/catalog/domain/catalog_repository.dart';

import 'test_catalog.dart';

/// Pumps the whole app on a 390 x 844 phone screen with the small test catalog
/// instead of the demo data.
///
/// Signed in as the demo customer, unless [signedIn] is false: the checkout and
/// the orders need an account, and most flows are about them.
Future<void> pumpZaba(
  WidgetTester tester, {
  List<Override> overrides = const [],
  DateTime? now,
  bool signedIn = true,
  CatalogRepository? catalog,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(
          catalog ??
              const InMemoryCatalogRepository(
                categoryList: testCategories,
                productList: testProducts,
              ),
        ),
        // A pinned clock keeps the delivery slots predictable, and the fake
        // payment provider answers at once.
        clockProvider.overrideWithValue(
          () => now ?? DateTime(2026, 10, 21, 10),
        ),
        paymentProcessingDelayProvider.overrideWithValue(Duration.zero),
        authRepositoryProvider.overrideWithValue(
          InMemoryAuthRepository(
            accounts: [offlineDemoAccount],
            signedInAs: signedIn ? offlineDemoAccount.email : null,
          ),
        ),
        ...overrides,
      ],
      child: const ZabaApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Lists are lazy: scrolls the main vertical list until [finder] has been
/// built and is visible.
Future<void> scrollListTo(WidgetTester tester, Finder finder) {
  return tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find
        .byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical)
        .first,
  );
}

/// The scrollable of the chip row (vegetarian toggle and categories). Not just
/// "the first horizontal Scrollable": the search field's text scrolls
/// horizontally too.
Finder get _chipRow => find
    .descendant(
      of: find.byWidgetPredicate(
        (w) => w is ListView && w.scrollDirection == Axis.horizontal,
      ),
      matching: find.byType(Scrollable),
    )
    .first;

/// The chip row builds only what is near the viewport; this brings it back to
/// its start, where the vegetarian toggle and the first chips are.
Future<void> scrollChipRowToStart(WidgetTester tester) async {
  await tester.drag(_chipRow, const Offset(2000, 0));
  await tester.pumpAndSettle();
}

/// Scrolls the chip row to the category chip called [name] and taps it.
Future<void> tapCategoryChip(WidgetTester tester, String name) async {
  final chip = find.widgetWithText(ChoiceChip, name);
  // From the start, so the chip is only ever ahead of the viewport.
  await scrollChipRowToStart(tester);
  await tester.scrollUntilVisible(chip, 100, scrollable: _chipRow);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Finder navTab(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

/// Fills in the delivery address dialog with a district V address.
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
