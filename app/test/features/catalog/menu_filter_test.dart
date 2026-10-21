import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/features/catalog/application/menu_filter.dart';

import '../../support/test_catalog.dart';

List<String> ids(List<dynamic> products) => [
  for (final p in products) p.id as String,
];

void main() {
  test('default filter keeps everything, most popular first', () {
    final result = applyMenuFilter(testProducts, const MenuFilter());

    expect(ids(result), ['carbonara', 'lemonade', 'arrabbiata', 'rantott']);
  });

  test(
    'search ignores case and Hungarian accents, and also looks at descriptions',
    () {
      expect(
        ids(applyMenuFilter(testProducts, const MenuFilter(query: 'RANTOTT'))),
        ['rantott'],
      );
      expect(
        ids(applyMenuFilter(testProducts, const MenuFilter(query: 'limonade'))),
        ['lemonade'],
      );
      expect(
        ids(applyMenuFilter(testProducts, const MenuFilter(query: 'citrom'))),
        ['lemonade'],
      );
      expect(
        applyMenuFilter(testProducts, const MenuFilter(query: 'nincs ilyen')),
        isEmpty,
      );
    },
  );

  test('category and vegetarian filters combine', () {
    final pasta = applyMenuFilter(
      testProducts,
      const MenuFilter(categoryId: 'pasta'),
    );
    expect(ids(pasta), ['carbonara', 'arrabbiata', 'rantott']);

    final vegetarianPasta = applyMenuFilter(
      testProducts,
      const MenuFilter(categoryId: 'pasta', vegetarianOnly: true),
    );
    expect(ids(vegetarianPasta), ['arrabbiata', 'rantott']);
  });

  test('sorts by price in both directions, ties broken by name', () {
    final cheapFirst = applyMenuFilter(
      testProducts,
      const MenuFilter(sort: MenuSort.priceAscending),
    );
    expect(ids(cheapFirst), ['lemonade', 'rantott', 'arrabbiata', 'carbonara']);

    final expensiveFirst = applyMenuFilter(
      testProducts,
      const MenuFilter(sort: MenuSort.priceDescending),
    );
    expect(ids(expensiveFirst), [
      'carbonara',
      'arrabbiata',
      'rantott',
      'lemonade',
    ]);
  });

  test(
    'the list is grouped only without a search text and without a price sort',
    () {
      expect(const MenuFilter().grouped, isTrue);
      expect(const MenuFilter(categoryId: 'pasta').grouped, isTrue);
      expect(const MenuFilter(query: 'x').grouped, isFalse);
      expect(const MenuFilter(sort: MenuSort.priceAscending).grouped, isFalse);
    },
  );
}
