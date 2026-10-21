import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/core/money/money.dart';
import 'package:zaba/features/catalog/data/supabase_catalog_repository.dart';
import 'package:zaba/features/catalog/domain/allergen.dart';

Map<String, dynamic> row({
  List<Object?> allergens = const ['gluten', 'milk'],
  Object? imagePath = 'carbonara.webp',
}) => {
  'id': 'carbonara',
  'category_id': 'pasta',
  'name': 'Spagetti carbonara',
  'description': 'Tojásos-sajtos szósz.',
  'price_huf': 2790,
  'allergens': allergens,
  'vegetarian': false,
  'popularity': 95,
  'image_path': imagePath,
};

void main() {
  test('a category row becomes a category', () {
    final category = categoryFromRow({
      'id': 'pasta',
      'name': 'Tészták',
      'icon_key': 'pasta',
    });
    expect(category.id, 'pasta');
    expect(category.name, 'Tészták');
    expect(category.iconKey, 'pasta');
  });

  test('a product row becomes a product with every field', () {
    final product = productFromRow(row());
    expect(product.id, 'carbonara');
    expect(product.categoryId, 'pasta');
    expect(product.name, 'Spagetti carbonara');
    expect(product.description, 'Tojásos-sajtos szósz.');
    expect(product.price, const Money(2790));
    expect(product.allergens, {Allergen.gluten, Allergen.milk});
    expect(product.vegetarian, isFalse);
    expect(product.popularity, 95);
    expect(product.imagePath, 'carbonara.webp');
  });

  test('a product without a photo or allergens is fine', () {
    final product = productFromRow(row(allergens: [], imagePath: null));
    expect(product.allergens, isEmpty);
    expect(product.imagePath, isNull);
  });

  test('an unknown allergen code stops the load instead of vanishing', () {
    expect(
      () => productFromRow(row(allergens: ['gluten', 'kryptonite'])),
      throwsA(isA<FormatException>()),
    );
  });

  test('every allergen survives the trip through its database code', () {
    for (final allergen in Allergen.values) {
      expect(Allergen.fromCode(allergen.code), allergen);
    }
  });
}
