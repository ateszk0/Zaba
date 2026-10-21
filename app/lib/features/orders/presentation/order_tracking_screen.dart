import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/date_time_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../cart/presentation/widgets/price_summary.dart';
import '../../delivery/presentation/address_dialog.dart';
import '../application/order_providers.dart';
import '../domain/order.dart';
import '../domain/order_repository.dart';
import '../domain/order_status.dart';
import 'order_labels.dart';

class OrderTrackingScreen extends ConsumerWidget {
  const OrderTrackingScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final orderAsync = ref.watch(orderProvider(orderId));
    final order = orderAsync.value;

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.navOrders)),
        body: orderAsync.isLoading
            ? const LoadingView()
            : EmptyView(
                icon: Icons.search_off_rounded,
                title: l10n.orderNotFound,
              ),
      );
    }

    final paid = OrderStatus.timeline.contains(order.status);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.orderTitle(order.number))),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _StatusCard(order: order),
          if (order.status == OrderStatus.pendingPayment) ...[
            const SizedBox(height: AppSpacing.md),
            _PayCard(order: order),
          ],
          if (paid) ...[
            const SizedBox(height: AppSpacing.md),
            for (final status in OrderStatus.timeline)
              _TimelineRow(
                status: status,
                reached: status.index <= order.status.index,
                current: status == order.status,
                last: status == OrderStatus.timeline.last,
              ),
          ],
          if (order.status.isActive) ...[
            const SizedBox(height: AppSpacing.sm),
            _DeliveryWindow(order: order),
          ],
          if (ref.watch(kitchenSimulationProvider) && order.status.next != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.fast_forward_rounded),
                label: Text(l10n.orderAdvanceDemo),
                onPressed: () => ref
                    .read(orderAdminProvider)
                    .setStatus(order.id, order.status.next!),
              ),
            ),
          if (order.status.customerCanCancel) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => _confirmCancel(context, ref, order),
              child: Text(l10n.orderCancel),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _SummaryCard(order: order),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    Order order,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.orderCancelTitle),
        content: Text(
          order.paymentStatus == PaymentStatus.succeeded
              ? l10n.orderCancelBodyPaid
              : l10n.orderCancelBodyUnpaid,
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
    if (confirmed != true) {
      return;
    }
    try {
      await ref.read(orderRepositoryProvider).cancelOrder(order.id);
    } on OrderNotCancellableException {
      // The kitchen started between the tap and the answer: say why nothing
      // happened (the screen shows the new state by itself).
      messenger.showSnackBar(SnackBar(content: Text(l10n.orderCancelTooLate)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.orderCancelFailed)));
    }
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final (background, foreground) = order.status.colors;
    final timelineIndex = OrderStatus.timeline.indexOf(order.status);

    return Card(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg - 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(order.status.icon, color: foreground),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    order.status.title(l10n),
                    style: textTheme.headlineSmall?.copyWith(color: foreground),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              order.status.subtitle(l10n),
              style: textTheme.bodyMedium?.copyWith(color: foreground),
            ),
            if (timelineIndex >= 0) ...[
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: (timelineIndex + 1) / OrderStatus.timeline.length,
                  backgroundColor: AppColors.surface,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PayCard extends StatelessWidget {
  const _PayCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.orderPayNowTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.push('/pay/${order.id}'),
                child: Text(l10n.orderPayNow(order.total.format())),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryWindow extends StatelessWidget {
  const _DeliveryWindow({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final slot = order.slot;
    return Row(
      children: [
        const Icon(Icons.schedule_rounded, size: 20, color: AppColors.green700),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            AppLocalizations.of(context).orderDeliveryWindow(
              formatDate(slot.start),
              formatTimeRange(slot.start, slot.end),
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.status,
    required this.reached,
    required this.current,
    required this.last,
  });

  final OrderStatus status;
  final bool reached;
  final bool current;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final color = reached ? AppColors.green700 : AppColors.outlineStrong;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Icon(
                  reached
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: color,
                ),
                if (!last) Expanded(child: Container(width: 2, color: color)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: AppSpacing.md,
                left: AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.title(l10n),
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                      color: reached ? AppColors.ink : AppColors.inkMuted,
                    ),
                  ),
                  Text(status.subtitle(l10n), style: textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    Widget detail(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: textTheme.bodySmall)),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.orderSummarySection, style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in order.lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                detail(
                  l10n.orderAddressLabel,
                  formatAddress(l10n, order.address),
                ),
                detail(
                  l10n.orderSlotLabel,
                  '${formatDate(order.slot.start)} ${formatTimeRange(order.slot.start, order.slot.end)}',
                ),
                detail(l10n.orderPaymentLabel, order.paymentStatus.label(l10n)),
                if (order.note.isNotEmpty)
                  detail(l10n.orderNoteLabel, order.note),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
