import 'card_outcome.dart';

/// The one test card number the fake provider declines.
const declinedTestCard = '4000000000000002';

/// Luhn check on a number made only of digits, 13 to 19 of them.
bool isValidCardNumber(String digits) {
  if (digits.length < 13 || digits.length > 19) return false;
  var sum = 0;
  for (var i = 0; i < digits.length; i++) {
    final code = digits.codeUnitAt(digits.length - 1 - i) - 0x30;
    if (code < 0 || code > 9) return false;
    var value = code;
    if (i.isOdd) {
      value *= 2;
      if (value > 9) value -= 9;
    }
    sum += value;
  }
  return sum % 10 == 0;
}

/// `MM/YY` that is a real month and not in the past (the card is valid
/// through the end of the month).
bool isValidExpiry(String text, DateTime now) {
  final match = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(text);
  if (match == null) return false;
  final month = int.parse(match.group(1)!);
  final year = 2000 + int.parse(match.group(2)!);
  if (month < 1 || month > 12) return false;
  return year > now.year || (year == now.year && month >= now.month);
}

bool isValidCvc(String text) => RegExp(r'^\d{3}$').hasMatch(text);

/// The fake provider approves every valid card except [declinedTestCard].
CardOutcome outcomeForCardNumber(String digits) =>
    digits == declinedTestCard ? CardOutcome.declined : CardOutcome.approved;
