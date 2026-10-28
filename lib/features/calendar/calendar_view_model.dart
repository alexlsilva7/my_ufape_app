import 'package:flutter/foundation.dart';

const calendarPageAspectRatio = 3395 / 2400;

/// Maps the current São Paulo month to its page in the academic calendar.
int academicCalendarPage(DateTime now) {
  final date = now.toUtc().subtract(const Duration(hours: 3));
  final month = '${date.year}-${date.month.toString().padLeft(2, '0')}';
  const months = {
    '2026-03': 1,
    '2026-04': 2,
    '2026-05': 3,
    '2026-06': 5,
    '2026-07': 6,
    '2026-08': 7,
    '2026-09': 8,
    '2026-10': 9,
    '2026-11': 11,
    '2026-12': 12,
    '2027-01': 13,
    '2027-02': 14,
    '2027-03': 15,
    '2027-04': 16,
  };
  for (final entry in months.entries) {
    if (month.compareTo(entry.key) <= 0) return entry.value;
  }
  return 16;
}

class CalendarViewModel extends ChangeNotifier {
  CalendarViewModel({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      _page = academicCalendarPage((clock ?? DateTime.now)());

  final DateTime Function() _clock;
  int _page;
  int get page => _page;

  void setPage(int value) {
    final next = value.clamp(1, 16);
    if (next == _page) return;
    _page = next;
    notifyListeners();
  }

  void showCurrentMonth() => setPage(academicCalendarPage(_clock()));
}
