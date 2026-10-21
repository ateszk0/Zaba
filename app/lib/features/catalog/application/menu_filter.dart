import '../../../core/text/fold_text.dart';
import '../domain/product.dart';

enum MenuSort { popular, priceAscending, priceDescending }

class MenuFilter {
  const MenuFilter({
    this.query = '',
    this.categoryId,
    this.vegetarianOnly = false,
    this.sort = MenuSort.popular,
  });

  final String query;

  /// Null means all categories.
  final String? categoryId;
  final bool vegetarianOnly;
  final MenuSort sort;

  bool get isDefault =>
      query.trim().isEmpty &&
      categoryId == null &&
      !vegetarianOnly &&
      sort == MenuSort.popular;

  /// The list is shown in category sections only when nothing reorders or
  /// narrows it by text; otherwise it is one flat list.
  bool get grouped => query.trim().isEmpty && sort == MenuSort.popular;
}

/// Filters and sorts [products] for the menu screen. Search ignores case and
/// Hungarian accents and looks at the name and the description.
List<Product> applyMenuFilter(List<Product> products, MenuFilter filter) {
  final needle = foldText(filter.query.trim());
  final result = [
    for (final product in products)
      if ((filter.categoryId == null ||
              product.categoryId == filter.categoryId) &&
          (!filter.vegetarianOnly || product.vegetarian) &&
          (needle.isEmpty ||
              foldText(product.name).contains(needle) ||
              foldText(product.description).contains(needle)))
        product,
  ];

  int byName(Product a, Product b) =>
      foldText(a.name).compareTo(foldText(b.name));
  switch (filter.sort) {
    case MenuSort.popular:
      result.sort((a, b) {
        final byPopularity = b.popularity.compareTo(a.popularity);
        return byPopularity != 0 ? byPopularity : byName(a, b);
      });
    case MenuSort.priceAscending:
      result.sort((a, b) {
        final byPrice = a.price.forint.compareTo(b.price.forint);
        return byPrice != 0 ? byPrice : byName(a, b);
      });
    case MenuSort.priceDescending:
      result.sort((a, b) {
        final byPrice = b.price.forint.compareTo(a.price.forint);
        return byPrice != 0 ? byPrice : byName(a, b);
      });
  }
  return result;
}
