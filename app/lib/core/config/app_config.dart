/// Build-time configuration, injected with `--dart-define-from-file=config/<env>.json`.
/// Only public values belong here: whatever is in this class ends up in the
/// web build and in the APK.
abstract final class AppConfig {
  /// `dev`, `staging` or `demo`.
  static const env = String.fromEnvironment('APP_ENV', defaultValue: 'dev');

  /// Developer-only screens (component gallery) are hidden in the demo build.
  static const showDevTools = env != 'demo';

  /// The Supabase project. Both values are public by design (the anon key is
  /// only a role marker; the data is protected by row level security). Without
  /// them the app runs fully offline on its in-memory demo data.
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const hasBackend = supabaseUrl != '' && supabaseAnonKey != '';

  /// The pre-made demo customer behind the "sign in with the demo account"
  /// button. A throw-away account with invented data: anybody who opens the
  /// demo may use it, so it is not a secret. The button is hidden when unset.
  static const demoEmail = String.fromEnvironment('DEMO_EMAIL');
  static const demoPassword = String.fromEnvironment('DEMO_PASSWORD');
}
