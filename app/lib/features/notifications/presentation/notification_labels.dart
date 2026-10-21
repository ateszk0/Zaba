import '../../../l10n/generated/app_localizations.dart';
import '../../orders/domain/order_status.dart';
import '../../orders/presentation/order_labels.dart';
import '../domain/app_notification.dart';

extension AppNotificationText on AppNotification {
  String title(AppLocalizations l10n) => switch (status) {
    OrderStatus.received => l10n.notifReceivedTitle,
    OrderStatus.preparing => l10n.notifPreparingTitle,
    OrderStatus.outForDelivery => l10n.notifOutForDeliveryTitle,
    OrderStatus.delivered => l10n.notifDeliveredTitle,
    OrderStatus.cancelled => l10n.notifCancelledTitle,
    OrderStatus.pendingPayment => status.title(l10n),
  };

  String body(AppLocalizations l10n) => switch (status) {
    OrderStatus.received => l10n.notifReceivedBody,
    OrderStatus.preparing => l10n.notifPreparingBody,
    OrderStatus.outForDelivery => l10n.notifOutForDeliveryBody,
    OrderStatus.delivered => l10n.notifDeliveredBody,
    OrderStatus.cancelled =>
      refunded ? l10n.notifCancelledRefundedBody : l10n.notifCancelledBody,
    OrderStatus.pendingPayment => status.subtitle(l10n),
  };
}
