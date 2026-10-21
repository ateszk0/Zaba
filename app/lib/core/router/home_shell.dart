import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/cart/application/cart_providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';

/// Bottom navigation around the four main tabs. Each tab keeps its own
/// navigation stack and scroll position ([StatefulNavigationShell]).
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cartCount = ref.watch(cartItemCountProvider);

    Widget cartIcon(IconData icon) => Badge(
      isLabelVisible: cartCount > 0,
      label: Text('$cartCount'),
      child: Icon(icon),
    );

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.outline)),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.restaurant_menu_outlined),
              selectedIcon: const Icon(Icons.restaurant_menu_rounded),
              label: l10n.navMenu,
            ),
            NavigationDestination(
              icon: cartIcon(Icons.shopping_basket_outlined),
              selectedIcon: cartIcon(Icons.shopping_basket_rounded),
              label: l10n.navCart,
            ),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long_rounded),
              label: l10n.navOrders,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: l10n.navProfile,
            ),
          ],
        ),
      ),
    );
  }
}
