import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

/// Starts the Supabase client from the build's configuration. Only call it when
/// [AppConfig.hasBackend] is true. With [persistSession] false (the device's
/// storage is unusable) the customer stays signed in until the page is reloaded.
Future<SupabaseClient> initSupabase({bool persistSession = true}) async {
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    // Either a `sb_publishable_` key or the legacy anon JWT (the self-hosted
    // Realtime needs the JWT, see docs/decisions.md).
    publishableKey: AppConfig.supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
      persistSession: persistSession,
      // The apps use no email links, and on the web the URL fragment belongs to
      // the router: the client must not try to read a session out of it.
      detectSessionInUri: false,
    ),
  );
  return Supabase.instance.client;
}
