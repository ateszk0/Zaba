import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../application/cart_providers.dart';

/// Sticky "view cart" bar on the menu; hidden while the cart is empty.
class CartBar extends ConsumerWidget {
  const CartBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartItemCountProvider);
    if (count == 0) return const SizedBox.shrink();
    final subtotal = ref.watch(cartQuoteProvider).value?.subtotal;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm + 4),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => context.go('/cart'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    AppLocalizations.of(context).menuCartBar(count),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                if (subtotal != null)
                  Text(
                    subtotal.format(),
                    style: const TextStyle(
                      fontFeatures: AppTypography.priceFeatures,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
