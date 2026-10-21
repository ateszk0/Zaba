import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/clock.dart';
import '../../auth/application/auth_providers.dart';
import '../../orders/application/order_providers.dart';
import '../../orders/domain/order.dart';
import '../domain/app_notification.dart';

@immutable
class NotificationsState {
  const NotificationsState({
    this.items = const [],
    this.unread = 0,
    this.banner,
  });

  /// Newest first.
  final List<AppNotification> items;
  final int unread;

  /// The one shown at the top of the screen right now, if any.
  final AppNotification? banner;
}

/// The notifications of this visit. They belong to whoever is signed in: a
/// different person starts with none.
class NotificationsNotifier extends Notifier<NotificationsState> {
  static const _keep = 30;

  @override
  NotificationsState build() {
    ref.watch(sessionProvider);
    return const NotificationsState();
  }

  void add(AppNotification notification) {
    state = NotificationsState(
      items: [notification, ...state.items].take(_keep).toList(),
      unread: state.unread + 1,
      banner: notification,
    );
  }

  void dismissBanner() {
    if (state.banner == null) return;
    state = NotificationsState(items: state.items, unread: state.unread);
  }

  void markAllRead() {
    if (state.unread == 0) return;
    state = NotificationsState(items: state.items, banner: state.banner);
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, NotificationsState>(
      NotificationsNotifier.new,
    );

/// Shows a notification inside the app: a banner and an entry in the list.
class InAppNotifier implements NotificationSender {
  InAppNotifier(this._notifications);

  final NotificationsNotifier _notifications;

  @override
  void send(AppNotification notification) => _notifications.add(notification);
}

final notificationSenderProvider = Provider<NotificationSender>(
  (ref) => InAppNotifier(ref.watch(notificationsProvider.notifier)),
);

/// Turns every change of an order's status into a notification. Watched once, at
/// the root of the app, so a change is noticed whichever screen is open.
final orderNotificationsProvider = Provider<void>((ref) {
  if (ref.watch(sessionProvider) == null) return;
  final sender = ref.watch(notificationSenderProvider);
  final now = ref.watch(clockProvider);
  var counter = 0;
  ref.listen(ordersProvider, (previous, next) {
    final after = next.value;
    if (after == null) return;
    for (final change in statusChanges(previous?.value, after)) {
      final order = change.order;
      sender.send(
        AppNotification(
          id: '${order.id}-${counter++}',
          orderId: order.id,
          orderNumber: order.number,
          status: order.status,
          refunded: order.paymentStatus == PaymentStatus.refunded,
          createdAt: now(),
        ),
      );
    }
  });
});
