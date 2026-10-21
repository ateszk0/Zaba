import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../delivery/application/delivery_providers.dart';

/// Delivery terms of the current zone: waiting time, fee and minimum order.
class KitchenInfoStrip extends ConsumerWidget {
  const KitchenInfoStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zone = ref.watch(deliveryZoneProvider).value;
    if (zone == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        _Meta(
          Icons.schedule_rounded,
          l10n.kitchenEta(zone.etaMinMinutes, zone.etaMaxMinutes),
        ),
        _Meta(
          Icons.delivery_dining_rounded,
          l10n.kitchenDeliveryFee(zone.deliveryFee.format()),
        ),
        _Meta(
          Icons.receipt_long_rounded,
          l10n.kitchenMinOrder(zone.minOrder.format()),
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.green700),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
