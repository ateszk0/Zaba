import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/features/auth/domain/auth_rules.dart';

void main() {
  group('isPlausibleEmail', () {
    test('accepts ordinary addresses, ignoring surrounding spaces', () {
      expect(isPlausibleEmail('anna@example.com'), isTrue);
      expect(isPlausibleEmail('  anna.kovacs+zaba@mail.example.hu '), isTrue);
    });

    test('rejects text that cannot be an address', () {
      for (final bad in [
        '',
        'anna',
        'anna@',
        '@example.com',
        'a@b',
        'a b@c.d',
      ]) {
        expect(isPlausibleEmail(bad), isFalse, reason: bad);
      }
    });
  });

  group('safeReturnPath', () {
    test('keeps in-app paths with their query', () {
      expect(safeReturnPath('/checkout'), '/checkout');
      expect(safeReturnPath('/orders/abc?x=1'), '/orders/abc?x=1');
    });

    test('drops anything that is not an in-app path', () {
      for (final bad in [
        null,
        '',
        'checkout',
        'https://evil.example/',
        '//evil.example',
        r'/\evil.example',
        'javascript:alert(1)',
      ]) {
        expect(safeReturnPath(bad), isNull, reason: '$bad');
      }
    });

    test('never returns to the sign-in pages themselves', () {
      expect(safeReturnPath('/login'), isNull);
      expect(safeReturnPath('/register?from=%2Fcart'), isNull);
    });
  });
}
