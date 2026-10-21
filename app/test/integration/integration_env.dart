import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zaba/features/admin/domain/staff.dart';
import 'package:zaba/features/auth/data/supabase_auth_repository.dart';

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

SupabaseClient newIntegrationClient([
  String url = integrationUrl,
  String key = integrationKey,
]) => SupabaseClient(
  url,
  key,
  authOptions: AuthClientOptions(pkceAsyncStorage: _MemoryStorage()),
);

/// The secret (service-role) key of the test backend. Only the tests that need
/// to create staff accounts take it, with
/// `--dart-define=ZABA_TEST_SUPABASE_SECRET_KEY=<secret key>`: it is what may
/// make somebody staff, so it never belongs to a real project's tests.
const integrationSecretKey = String.fromEnvironment(
  'ZABA_TEST_SUPABASE_SECRET_KEY',
);

final Object staffIntegrationSkip = integrationSkip != false
    ? integrationSkip
    : (integrationSecretKey.isEmpty
          ? 'needs --dart-define=ZABA_TEST_SUPABASE_SECRET_KEY'
          : false);

var _staffCounter = 0;

/// A client signed in as a new throw-away account that is made staff with [role].
Future<SupabaseClient> newStaffClient(StaffRole role) async {
  final client = newIntegrationClient();
  await SupabaseAuthRepository(client.auth).signUp(
    email:
        'staff-${DateTime.now().microsecondsSinceEpoch}-${_staffCounter++}@example.test',
    password: 'hosszu-jelszo-1',
  );
  final service = newIntegrationClient(integrationUrl, integrationSecretKey);
  try {
    await service.from('admin_users').upsert({
      'user_id': client.auth.currentUser!.id,
      'role': role.name,
    });
  } finally {
    service.dispose();
  }
  return client;
}
