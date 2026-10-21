import 'package:flutter/material.dart';

import '../money/money.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/state_views.dart';

/// Developer-only gallery of the theme and the shared components, reachable
/// from the profile screen unless `APP_ENV=demo`. Its copy is deliberately not
/// localized: it exists to eyeball fonts (especially the Hungarian ő/ű glyphs),
/// colors and states on a real device.
class DesignGalleryScreen extends StatelessWidget {
  const DesignGalleryScreen({super.key});

  static const _pangram = 'Árvíztűrő tükörfúrógép';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Komponens-galéria')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: const [
          _Section('Színek', _Palette()),
          _Section('Betűtípusok és ékezetek', _Typography()),
          _Section('Árak', _Prices()),
          _Section('Gombok', _Buttons()),
          _Section('Űrlap és szűrők', _Inputs()),
          _Section('Állapotok', _States()),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.child);

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _Palette extends StatelessWidget {
  const _Palette();

  static const _swatches = {
    'green900': AppColors.green900,
    'green700': AppColors.green700,
    'green500': AppColors.green500,
    'green100': AppColors.green100,
    'green50': AppColors.green50,
    'tomato700': AppColors.tomato700,
    'tomato600': AppColors.tomato600,
    'tomato100': AppColors.tomato100,
    'cream': AppColors.cream,
    'ink': AppColors.ink,
    'inkMuted': AppColors.inkMuted,
    'outline': AppColors.outline,
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final entry in _swatches.entries)
          Column(
            children: [
              Container(
                width: 72,
                height: 48,
                decoration: BoxDecoration(
                  color: entry.value,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  border: Border.all(color: AppColors.outline),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(entry.key, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
      ],
    );
  }
}

class _Typography extends StatelessWidget {
  const _Typography();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final styles = {
      'headlineLarge · Baloo 2': t.headlineLarge,
      'headlineSmall · Baloo 2': t.headlineSmall,
      'titleMedium · Inter': t.titleMedium,
      'bodyLarge · Inter': t.bodyLarge,
      'bodyMedium · Inter': t.bodyMedium,
      'labelLarge · Inter': t.labelLarge,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in styles.entries) ...[
          Text(entry.key, style: t.labelSmall),
          Text(DesignGalleryScreen._pangram, style: entry.value),
          Text(DesignGalleryScreen._pangram.toUpperCase(), style: entry.value),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text('ő ű Ő Ű · „idézet” – 3 990 Ft', style: t.headlineMedium),
      ],
    );
  }
}

class _Prices extends StatelessWidget {
  const _Prices();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontFeatures: AppTypography.priceFeatures);
    const amounts = [
      Money(0),
      Money(990),
      Money(1290),
      Money(15000),
      Money(1234567),
      Money(-500),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final amount in amounts) Text(amount.format(), style: style),
      ],
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        FilledButton(onPressed: () {}, child: const Text('Kosárba')),
        FilledButton(
          onPressed: () {},
          style: FilledButton.styleFrom(backgroundColor: AppColors.tomato600),
          child: const Text('Megrendelem'),
        ),
        OutlinedButton(onPressed: () {}, child: const Text('Mégse')),
        TextButton(onPressed: () {}, child: const Text('Részletek')),
        const FilledButton(onPressed: null, child: Text('Letiltva')),
      ],
    );
  }
}

class _Inputs extends StatelessWidget {
  const _Inputs();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TextField(
          decoration: InputDecoration(labelText: 'Szállítási cím'),
        ),
        const SizedBox(height: AppSpacing.md),
        const TextField(
          decoration: InputDecoration(
            labelText: 'Irányítószám',
            errorText: 'Erre a címre nem szállítunk',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            FilterChip(
              label: const Text('Tészták'),
              selected: true,
              onSelected: (_) {},
            ),
            FilterChip(
              label: const Text('Saláták'),
              selected: false,
              onSelected: (_) {},
            ),
            FilterChip(
              label: const Text('Vegetáriánus'),
              selected: false,
              onSelected: (_) {},
            ),
          ],
        ),
      ],
    );
  }
}

class _States extends StatelessWidget {
  const _States();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final view in [
          const LoadingView(),
          ErrorView(onRetry: () {}),
          const EmptyView(
            icon: Icons.search_off_rounded,
            title: 'Nincs találat',
            body: 'Próbálj másik keresőszót.',
          ),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Card(child: SizedBox(height: 280, child: view)),
          ),
      ],
    );
  }
}
