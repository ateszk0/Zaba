import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/cart/presentation/cart_screen.dart';
import '../../features/catalog/presentation/image_credits_screen.dart';
import '../../features/catalog/presentation/menu_screen.dart';
import '../../features/checkout/presentation/checkout_screen.dart';
import '../../features/orders/presentation/order_tracking_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/payment/presentation/payment_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../config/app_config.dart';
import '../dev/design_gallery_screen.dart';
import 'home_shell.dart';

/// Exposed as a provider so later steps can add auth redirects that watch
/// the session without touching the widgets.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/menu',
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
