@Tags(['integration'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zaba/features/catalog/data/demo_catalog.dart';
import 'package:zaba/features/catalog/data/supabase_catalog_repository.dart';
import 'package:zaba/features/catalog/domain/category.dart';
import 'package:zaba/features/catalog/domain/product.dart';

import 'integration_env.dart';

// Reads the seeded menu through the real repository, as a guest. The seed is
// generated from the Dart demo data, so what comes back must be that data, field
// for field: this checks the whole read path (grants, row level security, the
// price view, the mapping).

String describeCategory(Category c) => '${c.id}|${c.name}|${c.iconKey}';

String describeProduct(Product p) => [
  p.id,
  p.categoryId,
  p.name,
  p.description,
  p.price.forint,
  (p.allergens.map((a) => a.code).toList()..sort()).join(','),
  p.vegetarian,
  p.popularity,
  p.imagePath,
].join('|');

void main() {
  late SupabaseClient client;
  late SupabaseCatalogRepository catalog;

  setUpAll(() {
    // flutter_test answers every HTTP request with an error; this test needs the
    // real network.
    HttpOverrides.global = null;
  });

  setUp(() {
    client = newIntegrationClient();
    catalog = SupabaseCatalogRepository(client);
  });
  tearDown(() => client.dispose());

  group('the menu from a real Supabase', () {
    test('the categories are the demo categories, in order', () async {
      final categories = await catalog.categories();
      expect(
        categories.map(describeCategory),
        demoCategories.map(describeCategory),
      );
    });

    test('the products are the demo products, price and all', () async {
      final products = await catalog.products();
      expect(products, hasLength(demoProducts.length));
      expect(
        products.map(describeProduct).toSet(),
        demoProducts.map(describeProduct).toSet(),
      );
    });

    test('the most popular product comes first', () async {
      final products = await catalog.products();
      final popularity = products.map((p) => p.popularity).toList();
      expect(popularity, [...popularity]..sort((a, b) => b.compareTo(a)));
    });
  }, skip: integrationSkip);
}
