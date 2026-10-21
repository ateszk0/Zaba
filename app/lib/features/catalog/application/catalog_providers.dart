import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/in_memory_catalog_repository.dart';
import '../domain/catalog_repository.dart';
import '../domain/category.dart';
import '../domain/product.dart';
import 'menu_filter.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => const InMemoryCatalogRepository(),
);

final categoriesProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(catalogRepositoryProvider).categories(),
);

final productsProvider = FutureProvider<List<Product>>(
  (ref) => ref.watch(catalogRepositoryProvider).products(),
);

class MenuFilterNotifier extends Notifier<MenuFilter> {
  @override
  MenuFilter build() => const MenuFilter();

  void setQuery(String query) => state = MenuFilter(
    query: query,
    categoryId: state.categoryId,
    vegetarianOnly: state.vegetarianOnly,
    sort: state.sort,
  );

  /// Selecting the already selected category clears the selection.
  void selectCategory(String? categoryId) => state = MenuFilter(
    query: state.query,
    categoryId: categoryId == state.categoryId ? null : categoryId,
    vegetarianOnly: state.vegetarianOnly,
    sort: state.sort,
  );

  void toggleVegetarian() => state = MenuFilter(
    query: state.query,
    categoryId: state.categoryId,
    vegetarianOnly: !state.vegetarianOnly,
    sort: state.sort,
  );

  void setSort(MenuSort sort) => state = MenuFilter(
    query: state.query,
    categoryId: state.categoryId,
    vegetarianOnly: state.vegetarianOnly,
    sort: sort,
  );

  void reset() => state = const MenuFilter();
}

final menuFilterProvider = NotifierProvider<MenuFilterNotifier, MenuFilter>(
  MenuFilterNotifier.new,
);

/// Products after the current search, category, vegetarian and sort settings.
/// The menu is only usable with its categories as well, so a failed category
/// load fails this too.
final visibleProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final filter = ref.watch(menuFilterProvider);
  final categories = ref.watch(categoriesProvider);
  if (categories.hasError) {
    return AsyncValue.error(categories.error!, categories.stackTrace!);
  }
  return ref
      .watch(productsProvider)
      .whenData((products) => applyMenuFilter(products, filter));
});

/// Loads the menu again after a failure.
void reloadMenu(WidgetRef ref) {
  ref.invalidate(categoriesProvider);
  ref.invalidate(productsProvider);
}
