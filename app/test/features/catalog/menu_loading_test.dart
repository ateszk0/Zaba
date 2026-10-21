import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/features/catalog/domain/catalog_repository.dart';
import 'package:zaba/features/catalog/domain/category.dart';
import 'package:zaba/features/catalog/domain/product.dart';

import '../../support/pump_zaba.dart';
import '../../support/test_catalog.dart';

/// A backend that is down until [up] is set.
class FlakyCatalog implements CatalogRepository {
  FlakyCatalog({this.categoriesFail = true, this.productsFail = true});

  final bool categoriesFail;
  final bool productsFail;
  var up = false;

  @override
  Future<List<Category>> categories() async {
    if (categoriesFail && !up) {
      throw Exception('offline');
    }
    return testCategories;
  }

  @override
  Future<List<Product>> products() async {
    if (productsFail && !up) {
      throw Exception('offline');
    }
    return testProducts;
  }
}

void main() {
  for (final (name, catalog) in [
    ('the products', FlakyCatalog(categoriesFail: false)),
    ('the categories', FlakyCatalog(productsFail: false)),
    ('both', FlakyCatalog()),
  ]) {
    testWidgets('when $name fail to load, the menu says so and Újra recovers', (
      tester,
    ) async {
      await pumpZaba(tester, catalog: catalog);
      expect(find.text('Hoppá, valami elromlott'), findsOneWidget);
      expect(find.text('Spagetti carbonara'), findsNothing);

      catalog.up = true;
      await tester.tap(find.text('Újra'));
      await tester.pumpAndSettle();

      expect(find.text('Hoppá, valami elromlott'), findsNothing);
      expect(find.text('Spagetti carbonara'), findsOneWidget);
    });
  }
}
