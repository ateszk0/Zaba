import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/core/theme/app_theme.dart';
import 'package:zaba/features/catalog/application/catalog_providers.dart';
import 'package:zaba/features/catalog/data/demo_catalog.dart';
import 'package:zaba/features/catalog/data/image_credits.dart';
import 'package:zaba/features/catalog/data/in_memory_catalog_repository.dart';
import 'package:zaba/features/catalog/domain/category.dart';
import 'package:zaba/features/catalog/domain/product.dart';
import 'package:zaba/features/catalog/presentation/widgets/product_image.dart';

import '../../support/pump_zaba.dart';
import '../../support/test_catalog.dart';

void main() {
  final withPhoto = demoProducts.where((p) => p.imagePath != null).toList();

  group('the product photo files', () {
    test('every product with an image path has its file', () {
      for (final product in withPhoto) {
        expect(
          File('assets/images/products/${product.imagePath}').existsSync(),
          isTrue,
          reason: '${product.id}: ${product.imagePath} is missing',
        );
      }
    });

    test('there are no photo files that no product uses', () {
      final used = {for (final p in withPhoto) p.imagePath};
      final files = Directory('assets/images/products')
          .listSync()
          .map((entity) => entity.uri.pathSegments.last)
          .toSet();

      expect(files, used);
    });

    test('exactly these products have no photo yet (they show the tile)', () {
      expect(
        demoProducts.where((p) => p.imagePath == null).map((p) => p.id).toSet(),
        {'chicken-paprikash', 'squash-stew', 'brasso', 'gundel-pancake'},
      );
    });

    test('every photo is credited (the licence asks for attribution)', () {
      expect(
        {for (final c in imageCredits) c.productId},
        {for (final p in withPhoto) p.id},
      );
      for (final credit in imageCredits) {
        expect(credit.author, isNotEmpty, reason: credit.productId);
        expect(
          credit.license,
          matches(RegExp(r'^(CC0|Public domain|CC BY \d\.\d)$')),
          reason: credit.productId,
        );
        expect(credit.pageUrl, startsWith('https://commons.wikimedia.org/'));
      }
    });

    test('the photos are small enough for a fast first load', () {
      final total = Directory('assets/images/products')
          .listSync()
          .whereType<File>()
          .fold<int>(0, (sum, file) => sum + file.lengthSync());

      // 41 photos; keep the whole set under 3 MB.
      expect(total, lessThan(3 * 1024 * 1024));
    });
  });

  group('ProductImage', () {
    Widget host(Widget child, {List<Category> categories = testCategories}) =>
        ProviderScope(
          overrides: [
            catalogRepositoryProvider.overrideWithValue(
              InMemoryCatalogRepository(categoryList: categories),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(body: child),
          ),
        );

    testWidgets('shows the photo of a product that has one', (tester) async {
      final carbonara = demoProducts.firstWhere((p) => p.id == 'carbonara');
      await tester.pumpWidget(host(ProductImage(product: carbonara)));

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('shows only the tile for a product without a photo', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(ProductImage(product: carbonara.copyWithoutImage())),
      );
      await tester.pump();

      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.ramen_dining_rounded), findsOneWidget);
    });

    testWidgets('takes the icon from the category, not from its id', (
      tester,
    ) async {
      // A category whose id says nothing about its icon (the server decides ids).
      await tester.pumpWidget(
        host(
          ProductImage(product: carbonara.copyWithoutImage()),
          categories: const [
            Category(id: 'pasta', name: 'Tészták', iconKey: 'soup'),
          ],
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.soup_kitchen_rounded), findsOneWidget);
      expect(find.byIcon(Icons.ramen_dining_rounded), findsNothing);
    });

    testWidgets('shows the generic icon for a category it does not know', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ProductImage(product: carbonara.copyWithoutImage()),
          categories: const [],
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
    });
  });

  testWidgets(
    'the credits screen is reachable from the profile and lists the sources',
    (tester) async {
      await pumpZaba(tester);
      await tester.tap(navTab('Profil'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Képek forrásai'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Wikimedia Commons'), findsOneWidget);
      expect(find.textContaining('Szerző:'), findsWidgets);
      expect(find.textContaining('CC'), findsWidgets);
      // Product names come from the catalog (the test catalog has the carbonara).
      expect(find.text('Spagetti carbonara'), findsOneWidget);
    },
  );
}

extension on Product {
  Product copyWithoutImage() => Product(
    id: id,
    categoryId: categoryId,
    name: name,
    description: description,
    price: price,
    allergens: allergens,
    vegetarian: vegetarian,
    popularity: popularity,
  );
}
