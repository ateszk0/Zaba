import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../cart/presentation/widgets/cart_bar.dart';
import '../../delivery/application/delivery_providers.dart';
import '../../delivery/presentation/address_dialog.dart';
import '../application/catalog_providers.dart';
import '../application/menu_filter.dart';
import '../domain/category.dart';
import '../domain/product.dart';
import 'category_icons.dart';
import 'widgets/kitchen_info_strip.dart';
import 'widgets/product_card.dart';

/// A row of the menu list: a category header or a product.
sealed class _MenuRow {
  const _MenuRow();
}

class _HeaderRow extends _MenuRow {
  const _HeaderRow(this.title);

  final String title;
}

class _ProductRow extends _MenuRow {
  const _ProductRow(this.product);

  final Product product;
}

List<_MenuRow> _buildRows(
  List<Product> products,
  List<Category> categories,
  MenuFilter filter,
) {
  if (!filter.grouped) {
    return [for (final product in products) _ProductRow(product)];
  }
  return [
    for (final category in categories) ...[
      if (products.any((product) => product.categoryId == category.id))
        _HeaderRow(category.name),
      for (final product in products)
        if (product.categoryId == category.id) _ProductRow(product),
    ],
  ];
}

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _resetFilters() {
    _search.clear();
    ref.read(menuFilterProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final filter = ref.watch(menuFilterProvider);
    final filterNotifier = ref.read(menuFilterProvider.notifier);
    final visible = ref.watch(visibleProductsProvider);
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final address = ref.watch(deliveryAddressProvider);

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  floating: true,
                  snap: true,
                  toolbarHeight: 64,
                  title: InkWell(
                    onTap: () => showAddressDialog(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.menuDeliverTo, style: textTheme.labelSmall),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  address == null
                                      ? l10n.menuAddressPlaceholder
                                      : formatAddress(l10n, address),
                                  style: textTheme.titleMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.expand_more_rounded),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    child: SearchBar(
                      controller: _search,
                      hintText: l10n.menuSearchHint,
                      leading: const Icon(Icons.search_rounded),
                      onChanged: filterNotifier.setQuery,
                      trailing: [
                        if (filter.query.isNotEmpty)
                          IconButton(
                            tooltip: l10n.menuSearchClear,
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _search.clear();
                              filterNotifier.setQuery('');
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: KitchenInfoStrip(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 56,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      children: [
                        FilterChip(
                          avatar: const Icon(Icons.eco_rounded, size: 18),
                          label: Text(l10n.menuVegetarian),
                          selected: filter.vegetarianOnly,
                          onSelected: (_) => filterNotifier.toggleVegetarian(),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        ChoiceChip(
                          label: Text(l10n.menuCategoryAll),
                          selected: filter.categoryId == null,
                          onSelected: (_) =>
                              filterNotifier.selectCategory(null),
                        ),
                        for (final category in categories) ...[
                          const SizedBox(width: AppSpacing.sm),
                          ChoiceChip(
                            avatar: Icon(
                              iconForCategoryKey(category.iconKey),
                              size: 18,
                            ),
                            label: Text(category.name),
                            selected: filter.categoryId == category.id,
                            onSelected: (_) =>
                                filterNotifier.selectCategory(category.id),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.md,
                      AppSpacing.xs,
                    ),
                    child: SegmentedButton<MenuSort>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: MenuSort.popular,
                          label: Text(l10n.menuSortPopular),
                        ),
                        ButtonSegment(
                          value: MenuSort.priceAscending,
                          label: Text(l10n.menuSortPriceAsc),
                        ),
                        ButtonSegment(
                          value: MenuSort.priceDescending,
                          label: Text(l10n.menuSortPriceDesc),
                        ),
                      ],
                      selected: {filter.sort},
                      onSelectionChanged: (selection) =>
                          filterNotifier.setSort(selection.first),
                    ),
                  ),
                ),
                ...visible.when(
                  loading: () => [
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: LoadingView(),
                    ),
                  ],
                  error: (error, stackTrace) => [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: ErrorView(onRetry: () => reloadMenu(ref)),
                    ),
                  ],
                  data: (products) {
                    if (products.isEmpty) {
                      return [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: filter.isDefault
                              ? EmptyView(
                                  icon: Icons.restaurant_menu_rounded,
                                  title: l10n.menuEmptyTitle,
                                  body: l10n.menuEmptyBody,
                                )
                              : EmptyView(
                                  icon: Icons.search_off_rounded,
                                  title: l10n.menuNoResultsTitle,
                                  body: l10n.menuNoResultsBody,
                                  action: OutlinedButton(
                                    onPressed: _resetFilters,
                                    child: Text(l10n.menuClearFilters),
                                  ),
                                ),
                        ),
                      ];
                    }
                    final rows = _buildRows(products, categories, filter);
                    return [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.sm,
                          AppSpacing.md,
                          AppSpacing.lg,
                        ),
                        sliver: SliverList.builder(
                          itemCount: rows.length,
                          itemBuilder: (context, index) =>
                              switch (rows[index]) {
                                _HeaderRow(:final title) => Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppSpacing.md,
                                    bottom: AppSpacing.sm,
                                  ),
                                  child: Text(
                                    title,
                                    style: textTheme.titleLarge,
                                  ),
                                ),
                                _ProductRow(:final product) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm + 4,
                                  ),
                                  child: ProductCard(product: product),
                                ),
                              },
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),
          ),
          const CartBar(),
        ],
      ),
    );
  }
}
