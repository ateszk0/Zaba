import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/money/money.dart';
import '../domain/allergen.dart';
import '../domain/catalog_repository.dart';
import '../domain/category.dart';
import '../domain/product.dart';

/// The menu from Supabase. Both reads are open to guests (row level security
/// lets everybody read active categories and products); inactive ones never
/// reach the app.
class SupabaseCatalogRepository implements CatalogRepository {
  SupabaseCatalogRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Category>> categories() async {
    final rows = await _client
        .from('categories')
        .select('id, name, icon_key')
        // `order` sorts descending unless told otherwise.
        .order('sort_order', ascending: true)
        .order('id', ascending: true);
    return rows.map(categoryFromRow).toList(growable: false);
  }

  @override
  Future<List<Product>> products() async {
    // The view joins each product with its current price.
    final rows = await _client
        .from('catalog_products')
        .select(
          'id, category_id, name, description, price_huf, allergens, '
          'vegetarian, popularity, image_path',
        )
        .order('popularity', ascending: false)
        .order('id', ascending: true);
    return rows.map(productFromRow).toList(growable: false);
  }
}

Category categoryFromRow(Map<String, dynamic> row) => Category(
  id: row['id'] as String,
  name: row['name'] as String,
  iconKey: row['icon_key'] as String,
);

/// Throws a [FormatException] for an allergen code the app does not know.
Product productFromRow(Map<String, dynamic> row) => Product(
  id: row['id'] as String,
  categoryId: row['category_id'] as String,
  name: row['name'] as String,
  description: row['description'] as String,
  price: Money(row['price_huf'] as int),
  allergens: {
    for (final code in row['allergens'] as List<dynamic>)
      Allergen.fromCode(code as String),
  },
  vegetarian: row['vegetarian'] as bool,
  popularity: row['popularity'] as int,
  imagePath: row['image_path'] as String?,
);
