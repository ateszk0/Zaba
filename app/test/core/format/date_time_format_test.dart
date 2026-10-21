import 'package:flutter_test/flutter_test.dart';
import 'package:zaba/core/format/date_time_format.dart';

void main() {
  test('formats clock time with leading zeros', () {
    expect(formatClock(DateTime(2026, 10, 21, 9, 5)), '09:05');
    expect(formatClock(DateTime(2026, 10, 21, 21, 30)), '21:30');
  });

  test('formats a date the Hungarian way', () {
    expect(formatDate(DateTime(2026, 1, 3)), '2026. 01. 03.');
    expect(formatDate(DateTime(2026, 10, 21)), '2026. 10. 21.');
  });

  test('formats a time range with an en dash', () {
    expect(
      formatTimeRange(DateTime(2026, 10, 21, 12), DateTime(2026, 10, 21, 13)),
      '12:00–13:00',
    );
  });
}
