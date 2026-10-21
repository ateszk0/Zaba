import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zaba/core/storage/preferences.dart';

class _BlockedStore extends SharedPreferencesStorePlatform {
  @override
  Future<Map<String, Object>> getAll() async =>
      throw StateError('Storage is blocked.');

  @override
  Future<bool> clear() async => false;

  @override
  Future<bool> remove(String key) async => false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;
}

void main() {
  test('opens the preferences when the storage works', () async {
    SharedPreferences.setMockInitialValues({'a': 'b'});

    final preferences = await openPreferences();

    expect(preferences?.getString('a'), 'b');
  });

  test('returns null, not an error, when the storage is blocked', () async {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = _BlockedStore();

    expect(await openPreferences(), isNull);
  });
}
