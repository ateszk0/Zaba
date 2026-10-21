/// An amount of Hungarian forints (HUF), always a whole number.
///
/// Money is never a `double`: HUF has no minor unit in practice, and the server
/// stores and calculates amounts as integers. The client only displays amounts
/// and does the trivial arithmetic needed for previews; authoritative totals
/// always come from the server.
extension type const Money(int forint) {
  static const zero = Money(0);

  static const _nbsp = '\u00A0';
  static const _minus = '\u2212';

  static Money sum(Iterable<Money> amounts) =>
      Money(amounts.fold(0, (total, amount) => total + amount.forint));

  Money operator +(Money other) => Money(forint + other.forint);

  Money operator -(Money other) => Money(forint - other.forint);

  Money operator *(int quantity) => Money(forint * quantity);

  bool operator <(Money other) => forint < other.forint;

  bool operator <=(Money other) => forint <= other.forint;

  bool operator >(Money other) => forint > other.forint;

  bool operator >=(Money other) => forint >= other.forint;

  /// Formats as `1 290 Ft`: non-breaking spaces (so an amount never wraps) and
  /// a real minus sign for negative values.
  String format() {
    final digits = forint.abs().toString();
    final grouped = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(_nbsp);
      grouped.write(digits[i]);
    }
    return '${forint < 0 ? _minus : ''}$grouped${_nbsp}Ft';
  }
}
