import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_providers.dart';
import '../application/admin_providers.dart';
import '../domain/staff.dart';
import 'admin_labels.dart';

/// The bar on every admin screen: who is signed in, the audit log (administrators
/// only), sign out.
class AdminAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const AdminAppBar({super.key, required this.title, this.leading});

  final String title;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(sessionProvider);
    final role = ref.watch(staffRoleProvider).value;
    final wide = MediaQuery.sizeOf(context).width >= 720;

    return AppBar(
      leading: leading,
      title: Text(title),
      actions: [
        if (user != null && wide)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Text(
              user.email,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (role != null)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: Chip(
              label: Text(role.label(l10n)),
              visualDensity: VisualDensity.compact,
              backgroundColor: AppColors.green100,
              side: BorderSide.none,
            ),
          ),
        if (role == StaffRole.admin)
          IconButton(
            tooltip: l10n.adminAuditTooltip,
            icon: const Icon(Icons.history_rounded),
            onPressed: () => context.go('/audit'),
          ),
        IconButton(
          tooltip: l10n.profileSignOut,
          icon: const Icon(Icons.logout_rounded),
          onPressed: () => ref.read(authRepositoryProvider).signOut(),
        ),
      ],
    );
  }
}
