import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/date_time_format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../cart/presentation/widgets/price_summary.dart';
import '../../../delivery/presentation/address_dialog.dart';
import '../../../orders/domain/order.dart';
import '../../../orders/domain/order_repository.dart';
import '../../../orders/domain/order_status.dart';
import '../../../orders/presentation/order_labels.dart';
import '../../../orders/presentation/widgets/order_status_chip.dart';
import '../../application/admin_providers.dart';
import '../../domain/admin_repository.dart';
import '../../domain/order_history.dart';
import '../admin_labels.dart';

/// One order for the kitchen: what to do next, what was ordered, where it goes,
/// and what happened to it so far. The buttons are the moves the database's
/// state machine allows an operator; nothing here decides what is allowed.
class AdminOrderDetail extends ConsumerStatefulWidget {
  const AdminOrderDetail({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<AdminOrderDetail> createState() => _AdminOrderDetailState();
}

class _AdminOrderDetailState extends ConsumerState<AdminOrderDetail> {
  var _busy = false;

  Future<void> _move(Order order, OrderStatus target) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (target == OrderStatus.cancelled && !await _confirmCancel(order)) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).setStatus(order.id, target);
      // Show the result at once; the live connection would also bring it.
      ref
        ..invalidate(adminOrderProvider(order.id))
        ..invalidate(orderHistoryProvider(order.id))
        ..invalidate(adminOrdersProvider);
    } on InvalidOrderTransitionException {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.adminActionNotAllowed)),
      );
    } on StaffOnlyException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.adminNoAccessTitle)));
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.adminActionFailed)));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<bool> _confirmCancel(Order order) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.orderCancelTitle),
        content: Text(
          order.paymentStatus == PaymentStatus.succeeded
              ? l10n.adminCancelBodyPaid
              : l10n.adminCancelBodyUnpaid,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.orderCancelKeep),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.orderCancelConfirm),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final orderAsync = ref.watch(adminOrderProvider(widget.orderId));
    final order = orderAsync.value;

    if (order == null) {
      if (orderAsync.isLoading) {
        return const LoadingView();
      }
      if (orderAsync.hasError) {
        return ErrorView(
          onRetry: () => ref.invalidate(adminOrderProvider(widget.orderId)),
        );
      }
      return EmptyView(
        icon: Icons.search_off_rounded,
        title: l10n.adminOrderNotFound,
      );
    }

    final textTheme = Theme.of(context).textTheme;
    final transitions =
        ref.watch(operatorTransitionsProvider).value ?? const {};
    final moves = [...?transitions[order.status]]
      ..sort((a, b) => a.index.compareTo(b.index));
    final history = ref.watch(orderHistoryProvider(widget.orderId)).value;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(order.number, style: textTheme.headlineSmall),
                ),
                OrderStatusChip(status: order.status),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.orderDeliveryWindow(
                formatDate(order.slot.start),
                formatTimeRange(order.slot.start, order.slot.end),
              ),
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            _Card(
              title: l10n.adminActionsTitle,
              child: _Actions(
                order: order,
                moves: moves,
                busy: _busy,
                onMove: (target) => _move(order, target),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _Card(
              title: l10n.orderSummarySection,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in order.lines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.checkoutQuantityTimes(
                                line.quantity,
                                line.name,
                              ),
                            ),
                          ),
                          Text(
                            line.total.format(),
                            style: TextStyle(
                              fontFeatures: AppTypography.priceFeatures,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: AppSpacing.lg),
                  PriceSummary(
                    subtotal: order.subtotal,
                    deliveryFee: order.deliveryFee,
                  ),
                  const Divider(height: AppSpacing.lg),
                  _Detail(
                    l10n.orderAddressLabel,
                    formatAddress(l10n, order.address),
                  ),
                  _Detail(
                    l10n.orderSlotLabel,
                    '${formatDate(order.slot.start)} ${formatTimeRange(order.slot.start, order.slot.end)}',
                  ),
                  _Detail(
                    l10n.orderPaymentLabel,
                    order.paymentStatus.label(l10n),
                  ),
                  if (order.note.isNotEmpty)
                    _Detail(l10n.orderNoteLabel, order.note),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _Card(
              title: l10n.adminHistoryTitle,
              child: history == null
                  ? const SizedBox(height: 24)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final change in history) _HistoryRow(change),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.order,
    required this.moves,
    required this.busy,
    required this.onMove,
  });

  final Order order;
  final List<OrderStatus> moves;
  final bool busy;
  final void Function(OrderStatus target) onMove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    if (moves.isEmpty) {
      return Text(l10n.adminNoActions, style: textTheme.bodyMedium);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (order.status == OrderStatus.pendingPayment) ...[
          Text(l10n.adminAwaitingPaymentHint, style: textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
        ],
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final target in moves)
              if (target == OrderStatus.cancelled)
                OutlinedButton(
                  onPressed: busy ? null : () => onMove(target),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.tomato700,
                  ),
                  child: Text(adminActionLabel(l10n, target)),
                )
              else
                FilledButton(
                  onPressed: busy ? null : () => onMove(target),
                  child: Text(adminActionLabel(l10n, target)),
                ),
          ],
        ),
      ],
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: textTheme.bodySmall)),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow(this.change);

  final StatusChange change;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '${formatDate(change.at)} ${formatClock(change.at)}',
              style: textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              change.from == null
                  ? l10n.adminHistoryPlaced
                  : change.to.title(l10n),
              style: textTheme.bodyMedium,
            ),
          ),
          Text(change.actor.label(l10n), style: textTheme.bodySmall),
        ],
      ),
    );
  }
}
