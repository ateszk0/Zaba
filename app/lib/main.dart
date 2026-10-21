import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'features/auth/application/auth_providers.dart';
import 'features/auth/data/supabase_auth_repository.dart';
import 'features/catalog/application/catalog_providers.dart';
import 'features/catalog/data/supabase_catalog_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final overrides = <Override>[];
  if (AppConfig.hasBackend) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      // Either a `sb_publishable_` key or the legacy anon JWT (the self-hosted
      // Realtime needs the JWT, see docs/decisions.md).
      publishableKey: AppConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        // The app uses no email links, and on the web the URL fragment belongs
        // to the router: the client must not try to read a session out of it.
        detectSessionInUri: false,
      ),
    );
    final client = Supabase.instance.client;
    overrides.addAll([
      authRepositoryProvider.overrideWith(
        (ref) => SupabaseAuthRepository(client.auth),
      ),
      catalogRepositoryProvider.overrideWith(
        (ref) => SupabaseCatalogRepository(client),
      ),
    ]);
  }

  runApp(ProviderScope(overrides: overrides, child: const ZabaApp()));
}
