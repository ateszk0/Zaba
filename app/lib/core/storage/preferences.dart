import 'package:shared_preferences/shared_preferences.dart';

/// The device's key-value storage, or null when the browser refuses it (blocked
/// site data, some private windows). The app then still works: the cart and the
/// session just do not survive a reload.
Future<SharedPreferences?> openPreferences() async {
  try {
    return await SharedPreferences.getInstance();
  } catch (_) {
    return null;
  }
}
