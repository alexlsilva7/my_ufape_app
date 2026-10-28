import '../../../../core/models.dart';

const scheduleDays = [
  'Segunda',
  'Terça',
  'Quarta',
  'Quinta',
  'Sexta',
  'Sábado',
];

bool isTimetabledSession(Session session) =>
    session.day >= 1 &&
    session.day <= 6 &&
    session.startMinutes != null &&
    session.endMinutes != null &&
    session.endMinutes! > session.startMinutes!;

List<String> displayedScheduleDays(Iterable<Discipline> selected) =>
    selected.any(
      (d) => d.sessions.any((s) => s.day == 6 && isTimetabledSession(s)),
    )
    ? scheduleDays
    : scheduleDays.take(5).toList();

/// Time partitions shared by the timetable and long session placements.
class ScheduleWeekLayout {
  const ScheduleWeekLayout._(this.blocks, this.visible);
  final List<(int, int)> blocks;
  final bool Function(int minute) visible;

  factory ScheduleWeekLayout.calculate({
    required List<Discipline> selected,
    required List<Discipline> available,
    required String shift,
  }) {
    final source = selected.isNotEmpty ? selected : available;
    final shifts = source
        .expand((d) => d.sessions)
        .where((s) => s.startMinutes != null)
        .map((s) => scheduleShiftOf(s.startMinutes!))
        .toSet();
    if (shifts.isEmpty) shifts.addAll({'manha', 'tarde'});
    final canonical = <(int, int)>[
      (450, 510),
      (510, 570),
      (570, 630),
      (630, 690),
      (690, 750),
      (780, 840),
      (840, 900),
      (900, 960),
      (960, 1020),
      (1020, 1080),
      (1110, 1210),
      (1210, 1310),
    ];
    bool visible(int minute) =>
        shift == 'all' ||
        (shift == 'auto'
            ? shifts.contains(scheduleShiftOf(minute))
            : shift == scheduleShiftOf(minute));
    final intervals = canonical.where((p) => visible(p.$1)).toList();
    for (final offering in selected) {
      for (final session in offering.sessions) {
        if (session.startMinutes != null &&
            session.endMinutes != null &&
            session.endMinutes! > session.startMinutes! &&
            visible(session.startMinutes!)) {
          intervals.add((session.startMinutes!, session.endMinutes!));
        }
      }
    }
    final points = intervals.expand((p) => [p.$1, p.$2]).toSet().toList()
      ..sort();
    final blocks = <(int, int)>[];
    for (var i = 0; i + 1 < points.length; i++) {
      final a = points[i], b = points[i + 1];
      if (intervals.any((p) => a >= p.$1 && b <= p.$2)) blocks.add((a, b));
    }
    return ScheduleWeekLayout._(blocks, visible);
  }
}

String scheduleShiftOf(int minutes) => minutes < 750
    ? 'manha'
    : minutes < 1080
    ? 'tarde'
    : 'noite';
String scheduleTimeLabel(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
