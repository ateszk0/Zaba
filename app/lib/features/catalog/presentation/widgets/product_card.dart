import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/quantity_stepper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../cart/application/cart_providers.dart';
import '../../domain/product.dart';
import 'product_image.dart';
import 'product_sheet.dart';

class ProductCard extends ConsumerWidget {
  const ProductCard({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final quantity = ref.watch(
      cartProvider.select((cart) => cart[product.id] ?? 0),
    );
    final cart = ref.read(cartProvider.notifier);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showProductSheet(context, product),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md - 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductImage(product: product),
              const SizedBox(width: AppSpacing.md - 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      product.description,
                      style: textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Price left, button right. On a narrow screen (or with a big
                    // system font) the quantity stepper does not fit next to the
                    // price, so it moves to a line of its own instead of being cut.
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: AppSpacing.xs,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              product.price.format(),
                              style: textTheme.titleMedium?.copyWith(
                                fontFeatures: AppTypography.priceFeatures,
                              ),
                            ),
                            if (product.vegetarian) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Icon(
                                Icons.eco_rounded,
                                size: 18,
                                color: AppColors.green700,
                                semanticLabel: AppLocalizations.of(context)
                                    .productVegetarian,
                              ),
                            ],
                          ],
                        ),
                        if (quantity == 0)
                          IconButton.filled(
                            onPressed: () => cart.add(product.id),
                            tooltip: AppLocalizations.of(context).productAdd,
                            constraints: const BoxConstraints.tightFor(
                              width: 44,
                              height: 44,
                            ),
                            icon: const Icon(Icons.add_rounded),
                          )
                        else
                          QuantityStepper(
                            quantity: quantity,
                            onIncrement: () => cart.increment(product.id),
                            onDecrement: () => cart.decrement(product.id),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
