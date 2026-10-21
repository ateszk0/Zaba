import '../domain/catalog_repository.dart';
import '../domain/category.dart';
import '../domain/product.dart';
import 'demo_catalog.dart';

/// Serves the built-in demo catalog. Replaced by the Supabase-backed
/// repository once the backend exists; stays useful as a test double.
class InMemoryCatalogRepository implements CatalogRepository {
  const InMemoryCatalogRepository({
    this.categoryList = demoCategories,
    this.productList = demoProducts,
  });

  final List<Category> categoryList;
  final List<Product> productList;

  @override
  Future<List<Category>> categories() async => categoryList;

  @override
  Future<List<Product>> products() async => productList;
}
