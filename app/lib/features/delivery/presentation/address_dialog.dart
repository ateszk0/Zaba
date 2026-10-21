import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/delivery_providers.dart';
import '../domain/delivery_address.dart';

String formatAddress(AppLocalizations l10n, DeliveryAddress address) =>
    l10n.addressFormatted(address.postalCode, address.street);

Future<void> showAddressDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _AddressDialog(),
  );
}

class _AddressDialog extends ConsumerStatefulWidget {
  const _AddressDialog();

  @override
  ConsumerState<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends ConsumerState<_AddressDialog> {
  late final TextEditingController _postalCode;
  late final TextEditingController _street;
  String? _postalCodeError;
  String? _streetError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final current = ref.read(deliveryAddressProvider);
    _postalCode = TextEditingController(text: current?.postalCode ?? '');
    _street = TextEditingController(text: current?.street ?? '');
  }

  @override
  void dispose() {
    _postalCode.dispose();
    _street.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final postalCode = _postalCode.text.trim();
    final street = _street.text.trim();

    String? postalCodeError;
    if (postalCode.length != 4) {
      postalCodeError = l10n.addressErrorPostalCode;
    } else {
      final zone = await ref
          .read(deliveryZoneRepositoryProvider)
          .zoneForPostalCode(postalCode);
      if (zone == null) postalCodeError = l10n.addressErrorOutOfZone;
    }
    final streetError = street.isEmpty ? l10n.addressErrorStreet : null;

    if (!mounted) return;
    if (postalCodeError != null || streetError != null) {
      setState(() {
        _postalCodeError = postalCodeError;
        _streetError = streetError;
      });
      return;
    }

    setState(() => _saving = true);
    ref
        .read(deliveryAddressProvider.notifier)
        .set(DeliveryAddress(postalCode: postalCode, street: street));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.addressTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _postalCode,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: InputDecoration(
                labelText: l10n.addressPostalCode,
                errorText: _postalCodeError,
              ),
              onChanged: (_) => setState(() => _postalCodeError = null),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _street,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.addressStreet,
                errorText: _streetError,
              ),
              onChanged: (_) => setState(() => _streetError = null),
              onSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
