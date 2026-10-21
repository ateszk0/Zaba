import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/catalog_providers.dart';
import '../data/image_credits.dart';

/// Source and licence of the product photos. The CC BY licence asks for
/// attribution, so the app shows it.
class ImageCreditsScreen extends ConsumerWidget {
  const ImageCreditsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final names = {
      for (final product in ref.watch(productsProvider).value ?? const [])
        product.id: product.name,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.imageCreditsTitle)),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: imageCredits.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Text(l10n.imageCreditsIntro, style: textTheme.bodyMedium);
          }
          final credit = imageCredits[index - 1];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                names[credit.productId] ?? credit.productId,
                style: textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                l10n.imageCreditsEntry(
                  credit.title,
                  credit.author,
                  credit.license,
                ),
                style: textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}
