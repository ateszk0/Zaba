/// Build-time configuration, injected with `--dart-define-from-file=config/<env>.json`.
/// Only public values belong here: whatever is in this class ends up in the
/// web build and in the APK.
abstract final class AppConfig {
  /// `dev`, `staging` or `demo`.
  static const env = String.fromEnvironment('APP_ENV', defaultValue: 'dev');

  /// Developer-only screens (component gallery) are hidden in the demo build.
  static const showDevTools = env != 'demo';
}
