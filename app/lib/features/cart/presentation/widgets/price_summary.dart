import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Subtotal, delivery fee and total. All prices are gross (VAT included).
class PriceSummary extends StatelessWidget {
  const PriceSummary({
    super.key,
    required this.subtotal,
    required this.deliveryFee,
  });

  final Money subtotal;
  final Money deliveryFee;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        _Row(l10n.priceSubtotal, subtotal.format(), textTheme.bodyMedium),
        _Row(
          l10n.priceDeliveryFee,
          deliveryFee.forint == 0 ? l10n.priceFree : deliveryFee.format(),
          textTheme.bodyMedium,
        ),
        const Divider(height: AppSpacing.lg),
        _Row(
          l10n.priceTotal,
          (subtotal + deliveryFee).format(),
          textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, this.style);

  final String label;
  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final valueStyle = style?.copyWith(
      fontFeatures: AppTypography.priceFeatures,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}
