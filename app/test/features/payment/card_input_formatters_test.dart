import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/features/payment/presentation/card_input_formatters.dart';

TextEditingValue typed(TextInputFormatter formatter, String text) => formatter
    .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text));

void main() {
  group('CardNumberFormatter', () {
    final formatter = CardNumberFormatter();

    test('groups digits by four', () {
      expect(typed(formatter, '4242424242424242').text, '4242 4242 4242 4242');
      expect(typed(formatter, '42424').text, '4242 4');
    });

    test('drops everything that is not a digit', () {
      expect(typed(formatter, '4242-4242 abcd 4242').text, '4242 4242 4242');
    });

    test('keeps at most 19 digits', () {
      expect(typed(formatter, '1' * 25).text.replaceAll(' ', '').length, 19);
    });

    test('puts the caret at the end', () {
      final value = typed(formatter, '42424');
      expect(value.selection.baseOffset, value.text.length);
    });
  });

  group('ExpiryFormatter', () {
    final formatter = ExpiryFormatter();

    test('adds the slash after the month', () {
      expect(typed(formatter, '1').text, '1');
      expect(typed(formatter, '12').text, '12');
      expect(typed(formatter, '122').text, '12/2');
      expect(typed(formatter, '1227').text, '12/27');
    });

    test('keeps at most four digits and ignores non-digits', () {
      expect(typed(formatter, '12/2799').text, '12/27');
      expect(typed(formatter, 'ab').text, '');
    });
  });
}
