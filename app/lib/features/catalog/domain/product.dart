import '../../../core/money/money.dart';
import 'allergen.dart';

class Product {
  const Product({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.price,
    this.allergens = const {},
    this.vegetarian = false,
    this.popularity = 0,
    this.imagePath,
  });

  final String id;
  final String categoryId;
  final String name;
  final String description;

  /// Gross price (VAT included) in whole forints.
  final Money price;
  final Set<Allergen> allergens;
  final bool vegetarian;

  /// Higher is more popular; drives the default ordering.
  final int popularity;

  /// Path of the product photo relative to the image base URL, if there is one.
  final String? imagePath;
}
