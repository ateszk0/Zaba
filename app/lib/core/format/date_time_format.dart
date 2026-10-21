String _two(int value) => value.toString().padLeft(2, '0');

/// `12:05`
String formatClock(DateTime time) => '${_two(time.hour)}:${_two(time.minute)}';

/// `2026. 10. 21.`
String formatDate(DateTime date) =>
    '${date.year}. ${_two(date.month)}. ${_two(date.day)}.';

/// `12:00–13:00`
String formatTimeRange(DateTime start, DateTime end) =>
    '${formatClock(start)}–${formatClock(end)}';
