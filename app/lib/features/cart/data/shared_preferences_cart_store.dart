import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/cart_limits.dart';
import '../domain/cart_store.dart';

/// The cart in the browser's local storage (web) or the app's preferences. It
/// holds only product ids and quantities, never prices: they come from the
/// server when the cart is priced.
class SharedPreferencesCartStore implements CartStore {
  SharedPreferencesCartStore(this._preferences);

  final SharedPreferences _preferences;

  static const key = 'zaba.cart.v1';

  @override
  Map<String, int> load() {
    final text = _preferences.getString(key);
    if (text == null) {
      return const {};
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        return const {};
      }
      // Whatever is in storage may be old, edited or broken: take only what
      // makes sense.
      return {
        for (final MapEntry(key: id, value: quantity) in decoded.entries)
          if (quantity is int && quantity >= 1)
            id: quantity > maxLineQuantity ? maxLineQuantity : quantity,
      };
    } on FormatException {
      return const {};
    }
  }

  @override
  void save(Map<String, int> lines) {
    if (lines.isEmpty) {
      _preferences.remove(key);
    } else {
      _preferences.setString(key, jsonEncode(lines));
    }
  }
}
