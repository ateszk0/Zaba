import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/application/auth_providers.dart';
import 'presentation/admin_audit_screen.dart';
import 'presentation/admin_gate.dart';
import 'presentation/admin_login_screen.dart';
import 'presentation/admin_orders_screen.dart';

/// The only rule of the router is "sign in first"; whether the person is staff,
/// and which role, is decided by [AdminGate] on each screen.
@visibleForTesting
String? adminRedirect({required bool signedIn, required String path}) {
  final atLogin = path == '/login';
  if (!signedIn && !atLogin) {
    return '/login';
  }
  if (signedIn && atLogin) {
    return '/';
  }
  return null;
}

final adminRouterProvider = Provider<GoRouter>((ref) {
  // Re-runs the redirect whenever somebody signs in or out.
  final sessionChanged = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => sessionChanged.value++);
  ref.onDispose(sessionChanged.dispose);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: sessionChanged,
    redirect: (context, state) => adminRedirect(
      signedIn: ref.read(sessionProvider) != null,
      path: state.uri.path,
    ),
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const AdminGate(child: AdminOrdersScreen()),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (context, state) => AdminGate(
          child: AdminOrdersScreen(selectedId: state.pathParameters['id']),
        ),
      ),
      GoRoute(
        path: '/audit',
        builder: (context, state) =>
            const AdminGate(adminOnly: true, child: AdminAuditScreen()),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
