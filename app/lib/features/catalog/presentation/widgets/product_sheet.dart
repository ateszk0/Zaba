import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/quantity_stepper.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../cart/application/cart_providers.dart';
import '../../domain/product.dart';
import '../allergen_labels.dart';
import 'product_image.dart';

Future<void> showProductSheet(BuildContext context, Product product) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // On the root navigator, so the sheet covers the bottom navigation bar.
    useRootNavigator: true,
    builder: (_) => ProductSheet(product: product),
  );
}

/// Detail view of a product: picture, description, allergens, and the
/// quantity to add to the cart.
class ProductSheet extends ConsumerStatefulWidget {
  const ProductSheet({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends ConsumerState<ProductSheet> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final product = widget.product;
    final allergens = product.allergens.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProductImage(
              product: product,
              width: double.infinity,
              height: 160,
              iconSize: 64,
              borderRadius: AppRadius.control,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(product.name, style: textTheme.headlineSmall),
            if (product.vegetarian) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(
                    Icons.eco_rounded,
                    size: 18,
                    color: AppColors.green700,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    l10n.productVegetarian,
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.green700,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(product.description, style: textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.productAllergens, style: textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            if (allergens.isEmpty)
              Text(l10n.productNoAllergens, style: textTheme.bodyMedium)
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final allergen in allergens)
                    Chip(label: Text(allergen.label(l10n))),
                ],
              ),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.productAllergenNote, style: textTheme.bodySmall),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                QuantityStepper(
                  quantity: _quantity,
                  onIncrement: () => setState(() => _quantity++),
                  onDecrement: _quantity > 1
                      ? () => setState(() => _quantity--)
                      : null,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      ref
                          .read(cartProvider.notifier)
                          .add(product.id, quantity: _quantity);
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      l10n.productAddWithPrice(
                        (product.price * _quantity).format(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
