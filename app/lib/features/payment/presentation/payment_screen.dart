import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/clock/clock.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../orders/application/order_providers.dart';
import '../../orders/domain/order.dart';
import '../../orders/domain/order_status.dart';
import '../application/payment_providers.dart';
import '../domain/payment_service.dart';
import '../domain/card_outcome.dart';
import '../domain/card_validation.dart';
import 'card_input_formatters.dart';

/// The (fake) card payment screen. The card data stays in this form: only the
/// outcome is handed to the payment service, and the order changes only when
/// the backend receives the provider's event.
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _expiry = TextEditingController();
  final _cvc = TextEditingController();
  final _holder = TextEditingController();

  bool _processing = false;

  /// Set right before leaving, so the screen does not flash "not payable"
  /// while the order it just paid changes under it.
  bool _leaving = false;
  String? _error;

  @override
  void dispose() {
    _number.dispose();
    _expiry.dispose();
    _cvc.dispose();
    _holder.dispose();
    super.dispose();
  }

  void _openOrder() {
    _leaving = true;
    context.go('/orders/${widget.orderId}');
  }

  Future<void> _pay() async {
    if (!_formKey.currentState!.validate()) return;
    final outcome = outcomeForCardNumber(_number.text.replaceAll(' ', ''));
    setState(() {
      _processing = true;
      _error = null;
    });
    final PaymentStatus status;
    try {
      status = await ref
          .read(paymentServiceProvider)
          .submit(orderId: widget.orderId, outcome: outcome);
    } on PaymentUnavailableException {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = AppLocalizations.of(context).paymentUnavailable;
      });
      return;
    }
    if (!mounted) return;
    if (status == PaymentStatus.succeeded) {
      _openOrder();
      return;
    }
    setState(() {
      _processing = false;
      _error = AppLocalizations.of(context).paymentDeclined;
      _cvc.clear();
    });
  }

  Future<void> _cancel() async {
    setState(() => _processing = true);
    try {
      await ref
          .read(paymentServiceProvider)
          .submit(orderId: widget.orderId, outcome: CardOutcome.cancelled);
    } on PaymentUnavailableException {
      // The order simply stays waiting for payment; it can be paid from its
      // page later.
    }
    if (!mounted) return;
    _openOrder();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final orderAsync = ref.watch(orderProvider(widget.orderId));
    final order = orderAsync.value;

    final appBar = AppBar(
      title: Text(l10n.paymentTitle),
      leading: BackButton(onPressed: _processing ? null : _openOrder),
    );

    if (order == null) {
      return Scaffold(
        appBar: appBar,
        body: orderAsync.isLoading
            ? const LoadingView()
            : ErrorView(
                onRetry: () => ref.invalidate(orderProvider(widget.orderId)),
              ),
      );
    }

    if (order.status != OrderStatus.pendingPayment &&
        !_processing &&
        !_leaving) {
      return Scaffold(
        appBar: appBar,
        body: EmptyView(
          icon: Icons.info_outline_rounded,
          title: l10n.paymentNotPayableTitle,
          action: FilledButton(
            onPressed: _openOrder,
            child: Text(l10n.paymentNotPayableAction),
          ),
        ),
      );
    }

    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: appBar,
      bottomNavigationBar: DecoratedBox(
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
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _processing ? null : _pay,
                    child: _processing
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.surface,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm + 4),
                              Text(l10n.paymentProcessing),
                            ],
                          )
                        : Text(l10n.paymentPay(order.total.format())),
                  ),
                ),
                TextButton(
                  onPressed: _processing ? null : _cancel,
                  child: Text(l10n.paymentCancel),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.paymentAmountDue, style: textTheme.bodySmall),
                        Text(
                          order.total.format(),
                          style: textTheme.headlineSmall?.copyWith(
                            fontFeatures: AppTypography.priceFeatures,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    l10n.paymentOrderNumber(order.number),
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const _TestCardsHint(),
          const SizedBox(height: AppSpacing.lg),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _number,
                  enabled: !_processing,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CardNumberFormatter()],
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: l10n.paymentCardNumber,
                    prefixIcon: const Icon(Icons.credit_card_rounded),
                  ),
                  validator: (value) =>
                      isValidCardNumber((value ?? '').replaceAll(' ', ''))
                      ? null
                      : l10n.paymentErrorCardNumber,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _expiry,
                        enabled: !_processing,
                        keyboardType: TextInputType.number,
                        inputFormatters: [ExpiryFormatter()],
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: l10n.paymentExpiry,
                        ),
                        validator: (value) =>
                            isValidExpiry(
                              value ?? '',
                              ref.read(clockProvider)(),
                            )
                            ? null
                            : l10n.paymentErrorExpiry,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextFormField(
                        controller: _cvc,
                        enabled: !_processing,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(labelText: l10n.paymentCvc),
                        validator: (value) => isValidCvc(value ?? '')
                            ? null
                            : l10n.paymentErrorCvc,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _holder,
                  enabled: !_processing,
                  textCapitalization: TextCapitalization.words,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: l10n.paymentCardHolder,
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? l10n.paymentErrorHolder
                      : null,
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.tomato100,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.tomato700,
                    ),
                    const SizedBox(width: AppSpacing.sm + 4),
                    Expanded(
                      child: Text(
                        _error!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.tomato700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: AppColors.inkMuted,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.paymentSecurityNote,
                  style: textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TestCardsHint extends StatelessWidget {
  const _TestCardsHint();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.green50,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppColors.green100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.science_outlined,
                  size: 18,
                  color: AppColors.green700,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(l10n.paymentTestCardsTitle, style: textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.paymentTestCardsSuccess, style: textTheme.bodyMedium),
            Text(l10n.paymentTestCardsDeclined, style: textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.paymentTestCardsOther, style: textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
