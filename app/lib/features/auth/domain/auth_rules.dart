/// Mirrors `minimum_password_length` in supabase/config.toml: the server is the
/// authority, this only saves a round trip.
const minPasswordLength = 8;

/// The longest name the profile table accepts is 200 characters.
const maxFullNameLength = 100;

final _plausibleEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// A cheap sanity check, not a verification: the real test is whether the
/// server accepts the address.
bool isPlausibleEmail(String value) => _plausibleEmail.hasMatch(value.trim());

/// Only in-app paths may be used as the place to return to after signing in.
/// Anything else (another site, a protocol-relative `//host`, the sign-in
/// pages themselves) is dropped.
String? safeReturnPath(String? value) {
  if (value == null || !value.startsWith('/') || value.startsWith('//')) {
    return null;
  }
  if (value.contains(r'\')) {
    return null;
  }
  final path = Uri.tryParse(value)?.path;
  if (path == null || path == '/login' || path == '/register') {
    return null;
  }
  return value;
}
