import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/date_time_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/order_labels.dart';
import '../../orders/presentation/widgets/order_status_chip.dart';
import '../application/admin_providers.dart';
import 'admin_app_bar.dart';
import 'admin_labels.dart';
import 'widgets/admin_order_detail.dart';

/// The orders, live. On a wide screen the list and the selected order sit side
/// by side; on a phone-sized one each is a screen of its own.
class AdminOrdersScreen extends ConsumerWidget {
  const AdminOrdersScreen({super.key, this.selectedId});

  final String? selectedId;

  static const _wideFrom = 900.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= _wideFrom;

    if (wide) {
      return Scaffold(
        appBar: AdminAppBar(title: l10n.adminOrdersTitle),
        body: Row(
          children: [
            SizedBox(width: 440, child: _OrderList(selectedId: selectedId)),
            const VerticalDivider(width: 1),
            Expanded(
              child: selectedId == null
                  ? EmptyView(
                      icon: Icons.touch_app_outlined,
                      title: l10n.adminSelectOrder,
                    )
                  : AdminOrderDetail(
                      key: ValueKey(selectedId),
                      orderId: selectedId!,
                    ),
            ),
          ],
        ),
      );
    }

    if (selectedId != null) {
      return Scaffold(
        appBar: AdminAppBar(
          title: l10n.adminOrdersTitle,
          leading: IconButton(
            tooltip: l10n.adminBackToOrders,
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/'),
          ),
        ),
        body: AdminOrderDetail(key: ValueKey(selectedId), orderId: selectedId!),
      );
    }
    return Scaffold(
      appBar: AdminAppBar(title: l10n.adminOrdersTitle),
      body: const _OrderList(selectedId: null),
    );
  }
}

class _OrderList extends ConsumerWidget {
  const _OrderList({required this.selectedId});

  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(adminOrderFilterProvider);
    final orders = ref.watch(adminOrdersProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final option in AdminOrderFilter.values)
                ChoiceChip(
                  label: Text(option.label(l10n)),
                  selected: option == filter,
                  onSelected: (_) => ref
                      .read(adminOrderFilterProvider.notifier)
                      .select(option),
                ),
            ],
          ),
        ),
        Expanded(
          child: orders.when(
            loading: () => const LoadingView(),
            error: (error, stackTrace) =>
                ErrorView(onRetry: () => ref.invalidate(adminOrdersProvider)),
            data: (all) {
              final shown = filterAdminOrders(all, filter);
              if (shown.isEmpty) {
                return EmptyView(
                  icon: Icons.receipt_long_outlined,
                  title: l10n.adminOrdersEmptyTitle,
                  body: l10n.adminOrdersEmptyBody,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: shown.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) => _OrderTile(
                  order: shown[index],
                  selected: shown[index].id == selectedId,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.selected});

  final Order order;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      color: selected ? AppColors.green50 : null,
      child: InkWell(
        onTap: () => context.go('/orders/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(order.number, style: textTheme.titleMedium),
                  ),
                  Text(order.total.format(), style: textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${formatDate(order.slot.start)} ${formatTimeRange(order.slot.start, order.slot.end)}',
                style: textTheme.bodyMedium,
              ),
              Text(
                l10n.adminOrderPlaced(
                  formatClock(order.placedAt),
                  order.itemCount,
                ),
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OrderStatusChip(status: order.status),
                  Text(
                    order.paymentStatus.label(l10n),
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
