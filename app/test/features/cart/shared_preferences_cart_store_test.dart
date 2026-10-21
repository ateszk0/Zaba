import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zaba/features/cart/data/shared_preferences_cart_store.dart';

Future<SharedPreferences> preferencesWith([Object? saved]) {
  SharedPreferences.setMockInitialValues({
    SharedPreferencesCartStore.key: ?saved,
  });
  return SharedPreferences.getInstance();
}

Future<SharedPreferencesCartStore> storeWith([Object? saved]) async =>
    SharedPreferencesCartStore(await preferencesWith(saved));

void main() {
  test('what was saved comes back', () async {
    final store = await storeWith();
    expect(store.load(), isEmpty);

    store.save({'carbonara': 2, 'lemonade': 1});
    expect(store.load(), {'carbonara': 2, 'lemonade': 1});
  });

  test('an empty cart leaves nothing behind', () async {
    final preferences = await preferencesWith();
    final store = SharedPreferencesCartStore(preferences);

    store.save({'carbonara': 1});
    store.save({});

    expect(preferences.containsKey(SharedPreferencesCartStore.key), isFalse);
  });

  test('broken or foreign data is ignored, not trusted', () async {
    for (final broken in ['not json', '[1, 2]', '"text"', '']) {
      expect((await storeWith(broken)).load(), isEmpty, reason: broken);
    }
  });

  test('only sensible lines are taken from an old or edited save', () async {
    final store = await storeWith(
      '{"carbonara": 2, "zero": 0, "negative": -3, "text": "5", '
      '"fraction": 1.5, "huge": 5000, "missing": null}',
    );

    expect(store.load(), {'carbonara': 2, 'huge': 99});
  });
}
