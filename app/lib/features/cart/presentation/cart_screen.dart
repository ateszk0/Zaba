import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/quantity_stepper.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../catalog/presentation/widgets/product_image.dart';
import '../application/cart_providers.dart';
import '../domain/cart_quote.dart';
import 'widgets/price_summary.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final itemCount = ref.watch(cartItemCountProvider);

    if (itemCount == 0) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.navCart)),
        body: EmptyView(
          icon: Icons.shopping_basket_outlined,
          title: l10n.cartEmptyTitle,
          body: l10n.cartEmptyBody,
          action: FilledButton(
            onPressed: () => context.go('/menu'),
            child: Text(l10n.cartEmptyAction),
          ),
        ),
      );
    }

    // Only now: an empty cart is not priced.
    final quoteAsync = ref.watch(cartQuoteProvider);
    final quote = quoteAsync.value;

    if (quote == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.navCart)),
        body: quoteAsync.hasError
            ? ErrorView(onRetry: () => reloadCartQuote(ref))
            : const LoadingView(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navCart),
        actions: [
          TextButton(
            onPressed: ref.read(cartProvider.notifier).clear,
            child: Text(l10n.cartClear),
          ),
        ],
      ),
      bottomNavigationBar: _CheckoutBar(quote: quote),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          for (final line in quote.lines) _CartLineTile(line: line),
          if (quote.remainingForFreeDelivery case final remaining?) ...[
            const SizedBox(height: AppSpacing.sm),
            _FreeDeliveryHint(quote: quote, remaining: remaining),
          ],
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PriceSummary(
                    subtotal: quote.subtotal,
                    deliveryFee: quote.deliveryFee,
                  ),
                  if (quote.estimated) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.cartEstimatedFee,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.cartVatNote,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartLineTile extends ConsumerWidget {
  const _CartLineTile({required this.line});

  final QuoteLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final cart = ref.read(cartProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm + 4),
          child: Row(
            children: [
              ProductImage(
                product: line.product,
                width: 56,
                height: 56,
                iconSize: 26,
                borderRadius: 12,
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line.product.name, style: textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      line.total.format(),
                      style: textTheme.bodyMedium?.copyWith(
                        fontFeatures: AppTypography.priceFeatures,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              QuantityStepper(
                quantity: line.quantity,
                onIncrement: () => cart.increment(line.product.id),
                onDecrement: () => cart.decrement(line.product.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FreeDeliveryHint extends StatelessWidget {
  const _FreeDeliveryHint({required this.quote, required this.remaining});

  final CartQuote quote;
  final Money remaining;

  @override
  Widget build(BuildContext context) {
    final threshold = quote.freeDeliveryFrom!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).cartFreeDeliveryHint(remaining.format()),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: (quote.subtotal.forint / threshold.forint).clamp(0.0, 1.0),
            backgroundColor: AppColors.green100,
          ),
        ),
      ],
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.quote});

  final CartQuote quote;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm + 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!quote.meetsMinOrder)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  l10n.cartMinOrderShortfall(
                    quote.minOrderShortfall.format(),
                    quote.minOrder.format(),
                  ),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.error),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: quote.meetsMinOrder
                    ? () => context.push('/checkout')
                    : null,
                child: Text(l10n.cartCheckout(quote.total.format())),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
