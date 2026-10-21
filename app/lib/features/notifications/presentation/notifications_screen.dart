import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/date_time_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../orders/presentation/order_labels.dart';
import '../application/notification_providers.dart';
import 'notification_labels.dart';

/// The notifications of this visit, newest first. Opening the screen reads them.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Not while the tree is being built: that would change state mid-build.
    Future(() {
      if (mounted) {
        ref.read(notificationsProvider.notifier).markAllRead();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = ref.watch(notificationsProvider).items;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationsTitle)),
      body: items.isEmpty
          ? EmptyView(
              icon: Icons.notifications_none_rounded,
              title: l10n.notificationsEmptyTitle,
              body: l10n.notificationsEmptyBody,
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                for (final item in items)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        item.status.icon,
                        color: item.status.colors.$2,
                      ),
                      title: Text(item.title(l10n)),
                      subtitle: Text(
                        '${l10n.notificationOrder(item.orderNumber)} · ${item.body(l10n)}\n'
                        '${formatDate(item.createdAt)} ${formatClock(item.createdAt)}',
                      ),
                      isThreeLine: true,
                      onTap: () => context.go('/orders/${item.orderId}'),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.notificationsDemoNote,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }
}
