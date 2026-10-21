import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/demo_banner.dart';
import 'features/admin/admin_router.dart';
import 'l10n/generated/app_localizations.dart';

/// The admin page: the same look as the customer app, its own screens.
class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).adminTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: ref.watch(adminRouterProvider),
      locale: const Locale('hu'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => DemoFrame(
        label: AppLocalizations.of(context).adminBanner,
        child: child!,
      ),
    );
  }
}
