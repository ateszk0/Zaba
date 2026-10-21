import 'category.dart';
import 'product.dart';

abstract interface class CatalogRepository {
  /// Categories in display order.
  Future<List<Category>> categories();

  Future<List<Product>> products();
}
