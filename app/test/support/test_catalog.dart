import 'package:zaba/core/money/money.dart';
import 'package:zaba/features/catalog/domain/allergen.dart';
import 'package:zaba/features/catalog/domain/category.dart';
import 'package:zaba/features/catalog/domain/product.dart';

/// A tiny, stable catalog so tests do not depend on the demo data.
const testCategories = [
  Category(id: 'pasta', name: 'Tészták', iconKey: 'pasta'),
  Category(id: 'drink', name: 'Italok', iconKey: 'drink'),
];

const carbonara = Product(
  id: 'carbonara',
  categoryId: 'pasta',
  name: 'Spagetti carbonara',
  description: 'Tojásos-sajtos szósz.',
  price: Money(2790),
  allergens: {Allergen.gluten, Allergen.egg},
  popularity: 90,
);

const arrabbiata = Product(
  id: 'arrabbiata',
  categoryId: 'pasta',
  name: 'Penne arrabbiata',
  description: 'Csípős paradicsomszósz.',
  price: Money(2390),
  allergens: {Allergen.gluten},
  vegetarian: true,
  popularity: 70,
);

const lemonade = Product(
  id: 'lemonade',
  categoryId: 'drink',
  name: 'Házi limonádé',
  description: 'Friss citrom, menta.',
  price: Money(790),
  vegetarian: true,
  popularity: 80,
);

const rantott = Product(
  id: 'rantott',
  categoryId: 'pasta',
  name: 'Rántott sajt',
  description: 'Rántott, ropogós.',
  price: Money(2190),
  allergens: {Allergen.gluten, Allergen.milk},
  vegetarian: true,
  popularity: 50,
);

const testProducts = [carbonara, arrabbiata, lemonade, rantott];
