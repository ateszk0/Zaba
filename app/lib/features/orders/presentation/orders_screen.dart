import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/date_time_format.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_providers.dart';
import '../application/order_providers.dart';
import '../domain/order.dart';
import 'widgets/order_status_chip.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final signedIn = ref.watch(sessionProvider) != null;

    if (!signedIn) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.navOrders)),
        body: EmptyView(
          icon: Icons.lock_outline_rounded,
          title: l10n.ordersSignedOutTitle,
          body: l10n.ordersSignedOutBody,
          action: FilledButton(
            onPressed: () => context.push('/login?from=%2Forders'),
            child: Text(l10n.authLoginAction),
          ),
        ),
      );
    }

    final orders = ref.watch(ordersProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navOrders)),
      body: orders.when(
        loading: () => const LoadingView(),
        error: (error, stackTrace) =>
            ErrorView(onRetry: () => ref.invalidate(ordersProvider)),
        data: (orders) => orders.isEmpty
            ? EmptyView(
                icon: Icons.receipt_long_outlined,
                title: l10n.ordersEmptyTitle,
                body: l10n.ordersEmptyBody,
                action: FilledButton(
                  onPressed: () => context.go('/menu'),
                  child: Text(l10n.ordersEmptyAction),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: orders.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm + 4),
                itemBuilder: (context, index) =>
                    _OrderCard(order: orders[index]),
              ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/orders/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.number, style: textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      l10n.orderListSubtitle(
                        formatDate(order.placedAt),
                        formatClock(order.placedAt),
                        order.itemCount,
                      ),
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OrderStatusChip(status: order.status),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                order.total.format(),
                style: textTheme.titleMedium?.copyWith(
                  fontFeatures: AppTypography.priceFeatures,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
