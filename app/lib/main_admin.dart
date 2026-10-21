import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_app.dart';
import 'core/config/app_config.dart';
import 'core/supabase/supabase_bootstrap.dart';
import 'features/admin/application/admin_providers.dart';
import 'features/admin/data/supabase_admin_repository.dart';
import 'features/auth/application/auth_providers.dart';
import 'features/auth/data/supabase_auth_repository.dart';

/// Entry point of the admin page: `flutter build web -t lib/main_admin.dart`.
/// It is a separate build, so none of its code is in the customer app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!AppConfig.hasBackend) {
    runApp(const _MissingBackend());
    return;
  }
  final client = await initSupabase();
  runApp(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWith(
          (ref) => SupabaseAuthRepository(client.auth),
        ),
        adminRepositoryProvider.overrideWith(
          (ref) => SupabaseAdminRepository(client),
        ),
      ],
      child: const AdminApp(),
    ),
  );
}

/// The admin page works on the orders of a backend only: two separate apps
/// cannot share in-memory orders.
class _MissingBackend extends StatelessWidget {
  const _MissingBackend();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'A kezelőfelülethez Supabase kell: add meg a SUPABASE_URL és a '
              'SUPABASE_ANON_KEY értékét (--dart-define-from-file=config/dev.json).',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
