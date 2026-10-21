import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../data/in_memory_auth_repository.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

/// Offline by default; `main.dart` swaps in the Supabase implementation when
/// the build has a backend configured.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repository = InMemoryAuthRepository(accounts: [offlineDemoAccount]);
  ref.onDispose(repository.dispose);
  return repository;
});

/// Who is signed in right now (`null` for a guest). The router and the screens
/// watch this, so nothing else has to know about the auth stream.
final sessionProvider = NotifierProvider<SessionNotifier, AppUser?>(
  SessionNotifier.new,
);

class SessionNotifier extends Notifier<AppUser?> {
  @override
  AppUser? build() {
    final repository = ref.watch(authRepositoryProvider);
    final subscription = repository.userChanges.listen((user) => state = user);
    ref.onDispose(subscription.cancel);
    return repository.currentUser;
  }
}

class DemoCredentials {
  const DemoCredentials({required this.email, required this.password});

  final String email;
  final String password;
}

/// The account of the "sign in with the demo account" button, or `null` when
/// the build has none (the button is then hidden).
final demoCredentialsProvider = Provider<DemoCredentials?>((ref) {
  if (!AppConfig.hasBackend) {
    return DemoCredentials(
      email: offlineDemoAccount.email,
      password: offlineDemoAccount.password,
    );
  }
  if (AppConfig.demoEmail == '' || AppConfig.demoPassword == '') {
    return null;
  }
  return const DemoCredentials(
    email: AppConfig.demoEmail,
    password: AppConfig.demoPassword,
  );
});
