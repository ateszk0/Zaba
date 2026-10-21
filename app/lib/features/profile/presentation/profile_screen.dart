import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/domain/auth_repository.dart';
import '../../auth/presentation/auth_messages.dart';

/// The account and the demo notice, which must stay visible here.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider);
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navProfile)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Card(
            color: AppColors.tomato100,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.tomato700,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.profileDemoTitle,
                          style: textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(l10n.profileDemoBody, style: textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _AccountCard(user: user),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.profileImageCredits),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.go('/profile/credits'),
            ),
          ),
          if (AppConfig.showDevTools) ...[
            const SizedBox(height: AppSpacing.md),
            Card(
              child: ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: Text(l10n.profileDevGallery),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/dev/gallery'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.user});

  final AppUser? user;

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(authRepositoryProvider).signOut();
    } on AuthFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(authFailureMessage(l10n, failure.reason))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final user = this.user;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: user == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.profileSignedOutTitle,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(l10n.profileSignedOutBody, style: textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      FilledButton(
                        onPressed: () => context.push('/login'),
                        child: Text(l10n.authLoginAction),
                      ),
                      OutlinedButton(
                        onPressed: () => context.push('/register'),
                        child: Text(l10n.authRegisterTitle),
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.green100,
                        foregroundColor: AppColors.green900,
                        child: Text(
                          user.displayName.characters.first.toUpperCase(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              style: textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (user.fullName != null)
                              Text(
                                user.email,
                                style: textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () => _signOut(context, ref),
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(l10n.profileSignOut),
                  ),
                ],
              ),
      ),
    );
  }
}
