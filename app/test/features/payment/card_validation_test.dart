import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/features/payment/domain/card_outcome.dart';
import 'package:zaba/features/payment/domain/card_validation.dart';

void main() {
  group('isValidCardNumber (Luhn)', () {
    test('accepts well-known test numbers', () {
      expect(isValidCardNumber('4242424242424242'), isTrue);
      expect(isValidCardNumber('4000000000000002'), isTrue);
      expect(isValidCardNumber('5555555555554444'), isTrue);
    });

    test('rejects a wrong check digit, wrong length and non-digits', () {
      expect(isValidCardNumber('4242424242424241'), isFalse);
      expect(isValidCardNumber('424242424242'), isFalse);
      expect(isValidCardNumber('42424242424242424242'), isFalse);
      expect(isValidCardNumber('4242 4242 4242 4242'), isFalse);
      expect(isValidCardNumber(''), isFalse);
    });
  });

  group('isValidExpiry', () {
    final now = DateTime(2026, 10, 21);

    test('accepts the current month and later', () {
      expect(isValidExpiry('10/26', now), isTrue);
      expect(isValidExpiry('11/26', now), isTrue);
      expect(isValidExpiry('01/27', now), isTrue);
    });

    test('rejects the past, bad months and bad formats', () {
      expect(isValidExpiry('09/26', now), isFalse);
      expect(isValidExpiry('12/25', now), isFalse);
      expect(isValidExpiry('13/27', now), isFalse);
      expect(isValidExpiry('00/27', now), isFalse);
      expect(isValidExpiry('1/27', now), isFalse);
      expect(isValidExpiry('1027', now), isFalse);
      expect(isValidExpiry('', now), isFalse);
    });
  });

  test('a CVC is exactly three digits', () {
    expect(isValidCvc('123'), isTrue);
    expect(isValidCvc('12'), isFalse);
    expect(isValidCvc('1234'), isFalse);
    expect(isValidCvc('12a'), isFalse);
  });

  test('the fake provider declines only the dedicated test card', () {
    expect(outcomeForCardNumber('4000000000000002'), CardOutcome.declined);
    expect(outcomeForCardNumber('4242424242424242'), CardOutcome.approved);
    expect(outcomeForCardNumber('5555555555554444'), CardOutcome.approved);
  });
}
