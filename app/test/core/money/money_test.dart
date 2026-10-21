import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/core/money/money.dart';

void main() {
  group('Money.format', () {
    test('groups thousands with a non-breaking space and appends Ft', () {
      expect(const Money(0).format(), '0\u00A0Ft');
      expect(const Money(990).format(), '990\u00A0Ft');
      expect(const Money(1290).format(), '1\u00A0290\u00A0Ft');
      expect(const Money(15000).format(), '15\u00A0000\u00A0Ft');
      expect(const Money(1234567).format(), '1\u00A0234\u00A0567\u00A0Ft');
    });

    test('uses a real minus sign for negative amounts', () {
      expect(const Money(-500).format(), '\u2212500\u00A0Ft');
      expect(const Money(-12500).format(), '\u221212\u00A0500\u00A0Ft');
    });
  });

  group('Money arithmetic', () {
    test('adds and subtracts whole forints', () {
      expect(const Money(1290) + const Money(990), const Money(2280));
      expect(const Money(3500) - const Money(990), const Money(2510));
    });

    test('multiplies a unit price by a quantity', () {
      expect(const Money(1490) * 3, const Money(4470));
    });

    test('compares amounts', () {
      expect(const Money(990) < const Money(1490), isTrue);
      expect(const Money(1490) > const Money(990), isTrue);
      expect(const Money(990) <= const Money(990), isTrue);
      expect(const Money(990) >= const Money(1490), isFalse);
    });

    test('sums a collection, empty collection is zero', () {
      expect(
        Money.sum(const [Money(100), Money(250), Money(50)]),
        const Money(400),
      );
      expect(Money.sum(const []), Money.zero);
    });
  });
}
