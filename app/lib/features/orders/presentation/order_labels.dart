import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/order.dart';
import '../domain/order_status.dart';

extension OrderStatusPresentation on OrderStatus {
  String title(AppLocalizations l10n) => switch (this) {
    OrderStatus.pendingPayment => l10n.orderStatusPendingPaymentTitle,
    OrderStatus.received => l10n.orderStatusReceivedTitle,
    OrderStatus.preparing => l10n.orderStatusPreparingTitle,
    OrderStatus.outForDelivery => l10n.orderStatusOutForDeliveryTitle,
    OrderStatus.delivered => l10n.orderStatusDeliveredTitle,
    OrderStatus.cancelled => l10n.orderStatusCancelledTitle,
  };

  String subtitle(AppLocalizations l10n) => switch (this) {
    OrderStatus.pendingPayment => l10n.orderStatusPendingPaymentSubtitle,
    OrderStatus.received => l10n.orderStatusReceivedSubtitle,
    OrderStatus.preparing => l10n.orderStatusPreparingSubtitle,
    OrderStatus.outForDelivery => l10n.orderStatusOutForDeliverySubtitle,
    OrderStatus.delivered => l10n.orderStatusDeliveredSubtitle,
    OrderStatus.cancelled => l10n.orderStatusCancelledSubtitle,
  };

  IconData get icon => switch (this) {
    OrderStatus.pendingPayment => Icons.hourglass_top_rounded,
    OrderStatus.received => Icons.receipt_long_rounded,
    OrderStatus.preparing => Icons.soup_kitchen_rounded,
    OrderStatus.outForDelivery => Icons.delivery_dining_rounded,
    OrderStatus.delivered => Icons.check_circle_rounded,
    OrderStatus.cancelled => Icons.cancel_rounded,
  };

  /// Background and foreground of the status chip and card.
  (Color, Color) get colors => switch (this) {
    OrderStatus.pendingPayment => (AppColors.tomato100, AppColors.tomato700),
    OrderStatus.cancelled => (AppColors.outline, AppColors.inkMuted),
    _ => (AppColors.green100, AppColors.green900),
  };
}

extension PaymentStatusLabel on PaymentStatus {
  String label(AppLocalizations l10n) => switch (this) {
    PaymentStatus.pending => l10n.paymentStatusPending,
    PaymentStatus.succeeded => l10n.paymentStatusSucceeded,
    PaymentStatus.failed => l10n.paymentStatusFailed,
    PaymentStatus.cancelled => l10n.paymentStatusCancelled,
    PaymentStatus.refunded => l10n.paymentStatusRefunded,
  };
}
