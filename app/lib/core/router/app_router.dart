import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/domain/auth_rules.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/catalog/presentation/image_credits_screen.dart';
import '../../features/catalog/presentation/menu_screen.dart';
import '../../features/checkout/presentation/checkout_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/orders/presentation/order_tracking_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/payment/presentation/payment_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../config/app_config.dart';
import '../dev/design_gallery_screen.dart';
import 'home_shell.dart';

/// Browsing the menu and filling the cart is open to guests; ordering needs an
/// account. (The order list is a tab, so it shows a sign-in prompt itself.)
bool _needsSignIn(String path) =>
    path == '/checkout' ||
    path.startsWith('/pay/') ||
    path.startsWith('/orders/');

/// The auth rules of the router, apart from the router so they can be tested:
/// guests are sent to the sign-in page (remembering where they were heading),
/// and a signed-in person who lands on it directly (a bookmark, a reload with a
/// stored session) is sent on.
@visibleForTesting
String? authRedirect({required bool signedIn, required Uri location}) {
  final path = location.path;
  if (signedIn && (path == '/login' || path == '/register')) {
    return safeReturnPath(location.queryParameters['from']) ?? '/profile';
  }
  if (!signedIn && _needsSignIn(path)) {
    return Uri(
      path: '/login',
      queryParameters: {'from': location.toString()},
    ).toString();
  }
  return null;
}

/// Exposed as a provider so the redirects can watch the session without the
/// widgets knowing about them.
final routerProvider = Provider<GoRouter>((ref) {
  // Re-runs the redirect whenever somebody signs in or out.
  final sessionChanged = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => sessionChanged.value++);
  ref.onDispose(sessionChanged.dispose);

  final router = GoRouter(
    initialLocation: '/menu',
    refreshListenable: sessionChanged,
    redirect: (context, state) => authRedirect(
      signedIn: ref.read(sessionProvider) != null,
      location: state.uri,
    ),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/menu',
                builder: (context, state) => const MenuScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/cart',
                builder: (context, state) => const CartScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/orders',
                builder: (context, state) => const OrdersScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => OrderTrackingScreen(
                      orderId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'credits',
                    builder: (context, state) => const ImageCreditsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => AuthScreen(
          mode: AuthMode.login,
          returnTo: safeReturnPath(state.uri.queryParameters['from']),
        ),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => AuthScreen(
          mode: AuthMode.register,
          returnTo: safeReturnPath(state.uri.queryParameters['from']),
        ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/pay/:orderId',
        builder: (context, state) =>
            PaymentScreen(orderId: state.pathParameters['orderId']!),
      ),
      if (AppConfig.showDevTools)
        GoRoute(
          path: '/dev/gallery',
          builder: (context, state) => const DesignGalleryScreen(),
        ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
