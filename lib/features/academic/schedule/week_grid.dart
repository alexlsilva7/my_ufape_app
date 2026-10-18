import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models.dart';
import '../academic_motion.dart';
import '../academic_palette.dart';
import 'session_motion.dart';
import 'session_card.dart';
import 'week_layout.dart';

class ScheduleWeekGrid extends StatelessWidget {
  const ScheduleWeekGrid({
    super.key,
    required this.selected,
    required this.available,
    required this.shift,
    required this.scope,
    required this.availableHeight,
    required this.onDetails,
    required this.onToggle,
    this.onCompleted,
    this.disableMotion = false,
  });
  final List<Discipline> selected, available;
  final String shift;
  final Object scope;
  final double availableHeight;
  final bool disableMotion;
  final ValueChanged<Discipline> onDetails, onToggle;
  final ValueChanged<Discipline>? onCompleted;
  @override
  Widget build(BuildContext context) {
    final palette = AcademicPalette.of(context);
    final canvas = palette.canvas, ink = palette.ink, muted = palette.muted;
    Duration motion([int ms = 240]) =>
        academicMotionDuration(context, ms, disabled: disableMotion);
    final layout = ScheduleWeekLayout.calculate(
      selected: selected,
      available: available,
      shift: shift,
    );
    final blocks = layout.blocks;
    final visible = layout.visible;
    final days = displayedScheduleDays(selected);
    // A few selected time blocks should use the available height like the
    // original timetable. Dense schedules keep a compact minimum and scroll.
    final rowCount = blocks.isEmpty ? 1 : blocks.length;
    final rowHeight = ((availableHeight - 42) / rowCount)
        .clamp(
          144.0 +
              math.max(0, MediaQuery.textScalerOf(context).scale(12) - 12) * 6,
          440.0,
        )
        .toDouble();
    final border = Theme.of(context).colorScheme.outlineVariant
        .withValues(alpha: .6);
    return LayoutBuilder(
      builder: (context, constraints) {
        const timeWidth = 112.0;
        final dayWidth = (constraints.maxWidth - timeWidth) / days.length;
        return Column(
          children: [
            ColoredBox(
              color: canvas,
              child: Row(
                children: [
                  SizedBox(
                    width: timeWidth,
                    height: 42,
                    child: Center(
                      child: Text(
                        'Horário',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ),
                  for (final day in days)
                    SizedBox(
                      width: dayWidth,
                      height: 42,
                      child: Center(
                        child: Text(
                          day,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ink,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: motion(),
              curve: Curves.easeInOutCubic,
              height: blocks.length * rowHeight,
              child: Stack(
                children: [
                  for (var i = 0; i < blocks.length; i++)
                    AnimatedPositioned(
                      key: ValueKey((
                        'schedule-time',
                        blocks[i].$1,
                        blocks[i].$2,
                      )),
                      duration: motion(),
                      curve: Curves.easeInOutCubic,
                      left: 0,
                      right: 0,
                      top: i * rowHeight,
                      height: rowHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: border)),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: timeWidth,
                            child: ColoredBox(
                              color: canvas,
                              child: SizedBox(
                                height: rowHeight,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  spacing: 4,
                                  children: [
                                    Text(
                                      '${scheduleTimeLabel(blocks[i].$1)} - ${scheduleTimeLabel(blocks[i].$2)}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: ink,
                                      ),
                                    ),
                                    Text(
                                      switch (scheduleShiftOf(blocks[i].$1)) {
                                        'manha' => 'Manhã',
                                        'tarde' => 'Tarde',
                                        _ => 'Noite',
                                      },
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  for (var day = 0; day <= days.length; day++)
                    Positioned(
                      left: day == days.length
                          ? constraints.maxWidth - 1
                          : timeWidth + day * dayWidth,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 1, color: border),
                    ),
                  Positioned.fill(
                    child: ScheduleSessionLayer(
                      key: ValueKey(scope),
                      duration: motion(),
                      placements: [
                        for (final offering in selected)
                          for (final session in offering.sessions)
                            if (isTimetabledSession(session) &&
                                visible(session.startMinutes!) &&
                                blocks.any((b) => b.$1 == session.startMinutes))
                              _sessionBlock(
                                offering,
                                session,
                                blocks,
                                rowHeight,
                                timeWidth,
                                dayWidth,
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  ScheduleSessionPlacement _sessionBlock(
    Discipline offering,
    Session session,
    List<(int, int)> blocks,
    double rowHeight,
    double timeWidth,
    double dayWidth,
  ) {
    final start = blocks.indexWhere((b) => b.$1 == session.startMinutes);
    final span = blocks
        .where(
          (b) => b.$1 >= session.startMinutes! && b.$2 <= session.endMinutes!,
        )
        .length;
    return ScheduleSessionPlacement(
      id: 'schedule-session-${offering.id}-${session.day}-${session.time}',
      bounds: Rect.fromLTWH(
        timeWidth + (session.day - 1) * dayWidth + 4,
        start * rowHeight + 4,
        dayWidth - 8,
        (span * rowHeight - 8).clamp(48, double.infinity),
      ),
      child: ScheduleSessionCard(
        offering: offering,
        session: session,
        span: span,
        dayWidth: dayWidth,
        disableMotion: disableMotion,
        onDetails: () => onDetails(offering),
        onRemove: () => onToggle(offering),
        onCompleted: onCompleted == null ? null : () => onCompleted!(offering),
      ),
    );
  }
}
