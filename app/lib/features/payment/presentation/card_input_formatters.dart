import 'package:flutter/services.dart';

String _digitsOnly(String text) => text.replaceAll(RegExp(r'\D'), '');

TextEditingValue _atEnd(String text) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: text.length),
);

/// Digits only, in groups of four: `4242 4242 4242 4242`.
class CardNumberFormatter extends TextInputFormatter {
  static const maxDigits = 19;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = _digitsOnly(newValue.text);
    if (digits.length > maxDigits) digits = digits.substring(0, maxDigits);
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return _atEnd(buffer.toString());
  }
}

/// Digits only, with the slash added after the month: `12/27`.
class ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = _digitsOnly(newValue.text);
    if (digits.length > 4) digits = digits.substring(0, 4);
    final text = digits.length <= 2
        ? digits
        : '${digits.substring(0, 2)}/${digits.substring(2)}';
    return _atEnd(text);
  }
}
