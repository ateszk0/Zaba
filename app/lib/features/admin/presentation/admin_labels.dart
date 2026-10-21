import '../../../l10n/generated/app_localizations.dart';
import '../../orders/domain/order_status.dart';
import '../application/admin_providers.dart';
import '../domain/order_history.dart';
import '../domain/staff.dart';

extension StaffRoleLabel on StaffRole {
  String label(AppLocalizations l10n) => switch (this) {
    StaffRole.admin => l10n.adminRoleAdmin,
    StaffRole.operator => l10n.adminRoleOperator,
  };
}

extension AdminOrderFilterLabel on AdminOrderFilter {
  String label(AppLocalizations l10n) => switch (this) {
    AdminOrderFilter.active => l10n.adminFilterActive,
    AdminOrderFilter.awaitingPayment => l10n.adminFilterAwaitingPayment,
    AdminOrderFilter.closed => l10n.adminFilterClosed,
    AdminOrderFilter.all => l10n.adminFilterAll,
  };
}

extension ChangeActorLabel on ChangeActor {
  String label(AppLocalizations l10n) => switch (this) {
    ChangeActor.customer => l10n.adminActorCustomer,
    ChangeActor.operator => l10n.adminActorOperator,
    ChangeActor.payment => l10n.adminActorPayment,
  };
}

/// What the button that moves an order to this status says.
String adminActionLabel(AppLocalizations l10n, OrderStatus target) =>
    switch (target) {
      OrderStatus.preparing => l10n.adminActionPreparing,
      OrderStatus.outForDelivery => l10n.adminActionOutForDelivery,
      OrderStatus.delivered => l10n.adminActionDelivered,
      OrderStatus.cancelled => l10n.orderCancel,
      // The state machine has no operator move to these; the label is only here
      // so the switch stays exhaustive.
      OrderStatus.pendingPayment || OrderStatus.received => '',
    };
