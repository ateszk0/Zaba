import 'package:supabase_flutter/supabase_flutter.dart';

/// The backend the integration tests run against: the local stack from
/// `npx supabase start` (migrations and seed applied, email confirmation off):
///
///     flutter test test/integration \
///       --dart-define=ZABA_TEST_SUPABASE_URL=http://127.0.0.1:54321 \
///       --dart-define=ZABA_TEST_SUPABASE_KEY=<publishable or anon key>
///
/// The tests create throw-away accounts, so never point them at a real project.
const integrationUrl = String.fromEnvironment('ZABA_TEST_SUPABASE_URL');
const integrationKey = String.fromEnvironment('ZABA_TEST_SUPABASE_KEY');

/// Passed as `skip:` so that a plain `flutter test` leaves these tests out.
final Object integrationSkip = integrationUrl.isEmpty || integrationKey.isEmpty
    ? 'needs --dart-define=ZABA_TEST_SUPABASE_URL and ZABA_TEST_SUPABASE_KEY'
    : false;

/// What supabase_flutter keeps in shared preferences for the PKCE flow; a plain
/// Dart test has no preferences, so a map stands in.
class _MemoryStorage extends GotrueAsyncStorage {
  final _data = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _data[key];

  @override
  Future<void> setItem({required String key, required String value}) async =>
      _data[key] = value;

  @override
  Future<void> removeItem({required String key}) async => _data.remove(key);
}

SupabaseClient newIntegrationClient([String url = integrationUrl]) =>
    SupabaseClient(
      url,
      integrationKey,
      authOptions: AuthClientOptions(pkceAsyncStorage: _MemoryStorage()),
    );
