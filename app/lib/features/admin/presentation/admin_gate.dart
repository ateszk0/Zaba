import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/state_views.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_providers.dart';
import '../application/admin_providers.dart';
import '../domain/staff.dart';

/// Lets only staff through. Signed in but not staff is a normal case (a customer
/// who found the address), so it gets its own screen with a way out.
/// [adminOnly] screens are for the `admin` role: an operator sees the same
/// refusal.
class AdminGate extends ConsumerWidget {
  const AdminGate({super.key, required this.child, this.adminOnly = false});

  final Widget child;
  final bool adminOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(staffRoleProvider);
    return role.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (error, stackTrace) => Scaffold(
        body: ErrorView(onRetry: () => ref.invalidate(staffRoleProvider)),
      ),
      data: (role) {
        if (role == null || (adminOnly && role != StaffRole.admin)) {
          return const _NoAccess();
        }
        return child;
      },
    );
  }
}

class _NoAccess extends ConsumerWidget {
  const _NoAccess();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: EmptyView(
        icon: Icons.lock_outline_rounded,
        title: l10n.adminNoAccessTitle,
        body: l10n.adminNoAccessBody,
        action: OutlinedButton(
          onPressed: () => ref.read(authRepositoryProvider).signOut(),
          child: Text(l10n.profileSignOut),
        ),
      ),
    );
  }
}
