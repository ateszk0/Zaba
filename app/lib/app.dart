import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/demo_banner.dart';
import 'features/cart/application/cart_providers.dart';
import 'features/notifications/application/notification_providers.dart';
import 'features/notifications/presentation/notification_banner.dart';
import 'l10n/generated/app_localizations.dart';

class ZabaApp extends ConsumerWidget {
  const ZabaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(cartPruningProvider);
    ref.watch(orderNotificationsProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('hu'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) =>
          DemoFrame(below: const NotificationBanner(), child: child!),
    );
  }
}
