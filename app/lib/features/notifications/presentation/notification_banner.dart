import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../orders/presentation/order_labels.dart';
import '../application/notification_providers.dart';
import '../domain/app_notification.dart';
import 'notification_labels.dart';

/// The strip under the demo banner that announces a change of an order. It goes
/// away by itself after a few seconds; a tap opens the order.
class NotificationBanner extends ConsumerStatefulWidget {
  const NotificationBanner({
    super.key,
    this.visibleFor = const Duration(seconds: 7),
  });

  final Duration visibleFor;

  @override
  ConsumerState<NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends ConsumerState<NotificationBanner> {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _show(AppNotification? notification) {
    _timer?.cancel();
    if (notification != null) {
      _timer = Timer(
        widget.visibleFor,
        ref.read(notificationsProvider.notifier).dismissBanner,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      notificationsProvider.select((state) => state.banner),
      (_, banner) => _show(banner),
    );
    final notification = ref.watch(
      notificationsProvider.select((state) => state.banner),
    );
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: notification == null
          ? const SizedBox(width: double.infinity)
          : _Strip(notification: notification),
    );
  }
}

class _Strip extends ConsumerWidget {
  const _Strip({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final (background, foreground) = notification.status.colors;
    final notifications = ref.read(notificationsProvider.notifier);

    return SafeArea(
      bottom: false,
      child: Semantics(
        liveRegion: true,
        child: Material(
          color: background,
          child: InkWell(
            onTap: () {
              notifications.dismissBanner();
              ref.read(routerProvider).go('/orders/${notification.orderId}');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(notification.status.icon, color: foreground),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title(l10n),
                          style: textTheme.titleSmall?.copyWith(
                            color: foreground,
                          ),
                        ),
                        Text(
                          '${l10n.notificationOrder(notification.orderNumber)} · ${notification.body(l10n)}',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.ink,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // No tooltip: the banner sits above the app's Navigator, so there
                  // is no Overlay for a tooltip to open in. The label is for screen
                  // readers.
                  Semantics(
                    label: l10n.notificationDismiss,
                    button: true,
                    excludeSemantics: true,
                    child: IconButton(
                      icon: Icon(Icons.close_rounded, color: foreground),
                      onPressed: notifications.dismissBanner,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
