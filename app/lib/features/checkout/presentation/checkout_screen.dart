import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/clock/clock.dart';
import '../../../core/format/date_time_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../cart/application/cart_providers.dart';
import '../../cart/domain/cart_quote.dart';
import '../../cart/presentation/widgets/price_summary.dart';
import '../../delivery/application/delivery_providers.dart';
import '../../delivery/domain/delivery_address.dart';
import '../../delivery/domain/delivery_slot.dart';
import '../../delivery/presentation/address_dialog.dart';
import '../../orders/application/order_providers.dart';
import '../../orders/domain/order_repository.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _note = TextEditingController();

  /// One key per visit of this screen: tapping "place order" twice, or
  /// retrying after a lost response, can never create two orders.
  final _idempotencyKey =
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}';

  DateTime? _chosenDay;
  DeliverySlot? _chosenSlot;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _placeOrder(DeliveryAddress address, DeliverySlot slot) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final l10n = AppLocalizations.of(context);
    try {
      final order = await ref
          .read(orderRepositoryProvider)
          .placeOrder(
            PlaceOrderRequest(
              idempotencyKey: _idempotencyKey,
              lines: ref.read(cartProvider),
              address: address,
              slot: slot,
              note: _note.text,
            ),
          );
      if (!mounted) return;
      // The cart now lives on as the order, so it is emptied; the payment
      // screen replaces this one first so no empty cart flashes by.
      final cart = ref.read(cartProvider.notifier);
      context.pushReplacement('/pay/${order.id}');
      cart.clear();
    } on OrderRejectedException catch (rejection) {
      if (!mounted) return;
      if (rejection.reason == OrderRejection.slotUnavailable) {
        ref.invalidate(deliveryDaysProvider);
      }
      setState(() {
        _submitting = false;
        _error = switch (rejection.reason) {
          OrderRejection.emptyCart => l10n.orderErrorEmptyCart,
          OrderRejection.outOfDeliveryArea => l10n.orderErrorOutOfArea,
          OrderRejection.belowMinimumOrder => l10n.orderErrorBelowMinimum,
          OrderRejection.slotUnavailable => l10n.orderErrorSlotUnavailable,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final quoteAsync = ref.watch(cartQuoteProvider);
    final quote = quoteAsync.value;
    final address = ref.watch(deliveryAddressProvider);
    final days = ref.watch(deliveryDaysProvider).value ?? const <DeliveryDay>[];

    final day =
        days.where((d) => d.date == _chosenDay).firstOrNull ?? days.firstOrNull;
    final slot = (day != null && day.slots.contains(_chosenSlot))
        ? _chosenSlot
        : day?.slots.firstOrNull;

    if (quote == null || quote.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.checkoutTitle)),
        body: quote == null
            ? (quoteAsync.hasError
                  ? ErrorView(onRetry: () => ref.invalidate(cartQuoteProvider))
                  : const LoadingView())
            : EmptyView(
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

    final canPlace =
        !_submitting && address != null && slot != null && quote.meetsMinOrder;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkoutTitle)),
      bottomNavigationBar: _PlaceOrderBar(
        quote: quote,
        error: _error,
        submitting: _submitting,
        onPressed: canPlace ? () => _placeOrder(address, slot) : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _Section(
            title: l10n.checkoutAddressSection,
            child: Card(
              child: ListTile(
                leading: Icon(
                  Icons.location_on_outlined,
                  color: address == null ? AppColors.error : AppColors.green700,
                ),
                title: Text(
                  address == null
                      ? l10n.checkoutAddressMissing
                      : formatAddress(l10n, address),
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => showAddressDialog(context),
              ),
            ),
          ),
          _Section(
            title: l10n.checkoutSlotSection,
            child: days.isEmpty
                ? Text(l10n.checkoutNoSlots)
                : _SlotPicker(
                    days: days,
                    selectedDay: day!,
                    selectedSlot: slot,
                    onDay: (date) => setState(() {
                      _chosenDay = date;
                      _chosenSlot = null;
                    }),
                    onSlot: (value) => setState(() => _chosenSlot = value),
                  ),
          ),
          _Section(
            title: l10n.checkoutNoteSection,
            child: TextField(
              controller: _note,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.checkoutNoteLabel,
                hintText: l10n.checkoutNoteHint,
              ),
            ),
          ),
          _Section(
            title: l10n.checkoutPaymentSection,
            child: Card(
              child: ListTile(
                leading: const Icon(
                  Icons.credit_card_rounded,
                  color: AppColors.green700,
                ),
                title: Text(l10n.checkoutPaymentCard),
                subtitle: Text(l10n.checkoutPaymentDemoNote),
              ),
            ),
          ),
          _Section(
            title: l10n.checkoutSummarySection,
            child: _SummaryCard(quote: quote),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _SlotPicker extends ConsumerWidget {
  const _SlotPicker({
    required this.days,
    required this.selectedDay,
    required this.selectedSlot,
    required this.onDay,
    required this.onSlot,
  });

  final List<DeliveryDay> days;
  final DeliveryDay selectedDay;
  final DeliverySlot? selectedSlot;
  final ValueChanged<DateTime> onDay;
  final ValueChanged<DeliverySlot> onSlot;

  String _dayLabel(AppLocalizations l10n, DateTime date, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    if (date == today) return l10n.slotToday;
    if (date == DateTime(today.year, today.month, today.day + 1)) {
      return l10n.slotTomorrow;
    }
    return l10n.slotWeekdayDate(date.weekday.toString(), date.day);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final now = ref.watch(clockProvider)();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final day in days)
              ChoiceChip(
                label: Text(_dayLabel(l10n, day.date, now)),
                selected: day.date == selectedDay.date,
                onSelected: (_) => onDay(day.date),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final slot in selectedDay.slots)
              ChoiceChip(
                label: Text(formatTimeRange(slot.start, slot.end)),
                selected: slot == selectedSlot,
                onSelected: (_) => onSlot(slot),
              ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.quote});

  final CartQuote quote;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in quote.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        l10n.checkoutQuantityTimes(
                          line.quantity,
                          line.product.name,
                        ),
                      ),
                    ),
                    Text(
                      line.total.format(),
                      style: TextStyle(
                        fontFeatures: AppTypography.priceFeatures,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: AppSpacing.lg),
            PriceSummary(
              subtotal: quote.subtotal,
              deliveryFee: quote.deliveryFee,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.cartVatNote, style: textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _PlaceOrderBar extends StatelessWidget {
  const _PlaceOrderBar({
    required this.quote,
    required this.error,
    required this.submitting,
    required this.onPressed,
  });

  final CartQuote quote;
  final String? error;
  final bool submitting;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final message =
        error ??
        (quote.meetsMinOrder
            ? null
            : l10n.cartMinOrderShortfall(
                quote.minOrderShortfall.format(),
                quote.minOrder.format(),
              ));
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm + 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    message,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onPressed,
                  child: submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.surface,
                          ),
                        )
                      : Text(l10n.checkoutPlaceOrder(quote.total.format())),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
