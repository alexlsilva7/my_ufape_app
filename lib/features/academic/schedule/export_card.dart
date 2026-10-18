import 'package:flutter/material.dart';

import '../../../core/models.dart';
import '../../../core/theme/app_theme.dart';
import 'week_layout.dart';

/// A print composition, independent of screen theme, controls and scroll position.
class ScheduleExportCard extends StatelessWidget {
  const ScheduleExportCard({
    super.key,
    required this.courseName,
    required this.semester,
    required this.selected,
    required this.date,
  });

  static const logicalWidth = 1150.0;
  static const logoAsset = 'assets/images/my_ufape_logo.png';
  final String courseName, semester;
  final List<Discipline> selected;
  final DateTime date;
  static const _border = Color(0xffe2e8f0);
  static const _indigo = Color(0xff4f46e5);
  static const _titleStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    height: 1.4,
    fontWeight: FontWeight.w700,
    color: Color(0xff1e1b4b),
  );
  static const _professorStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: _indigo,
  );

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(
        textScaler: TextScaler.noScaling,
        disableAnimations: true,
      ),
      child: Theme(
        data: appTheme(Brightness.light),
        child: DefaultTextStyle(
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: Color(0xff334155),
          ),
          child: SizedBox(
            width: logicalWidth,
            child: ColoredBox(
              color: Colors.white,
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(),
                    const SizedBox(height: 24),
                    _grid(),
                    if (selected.any(
                      (d) => !d.sessions.any(isTimetabledSession),
                    )) ...[
                      const SizedBox(height: 24),
                      _unassigned(),
                    ],
                    const SizedBox(height: 24),
                    const Divider(height: 1, color: Color(0xfff1f5f9)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Grade organizada com My UFAPE',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xff94a3b8),
                          ),
                        ),
                        Text(
                          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xff94a3b8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _header() => Column(
    children: [
      Row(
        children: [
          Image.asset(logoAsset, width: 56, height: 56),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  spacing: 10,
                  children: [
                    const Text(
                      'My UFAPE',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.7,
                        color: Color(0xff0f172a),
                      ),
                    ),
                    _badge('GRADE HORÁRIA', fontSize: 12),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$courseName • Período $semester',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _indigo,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 5,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xfff1f5f9),
                  border: Border.all(color: _border),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${selected.length} ${selected.length == 1 ? 'matéria matriculada' : 'matérias matriculadas'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const Text(
                'Horário Acadêmico Oficial',
                style: TextStyle(fontSize: 11, color: Color(0xff94a3b8)),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 24),
      const Divider(height: 1, color: _border),
    ],
  );

  Widget _badge(String label, {double fontSize = 10}) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: fontSize == 12 ? 10 : 5,
      vertical: 3,
    ),
    decoration: BoxDecoration(
      color: fontSize == 12 ? const Color(0xffeef2ff) : const Color(0xffe0e7ff),
      border: fontSize == 12
          ? Border.all(color: const Color(0xffc7d2fe))
          : null,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: _indigo,
      ),
    ),
  );

  Widget _grid() {
    final days = displayedScheduleDays(selected);
    final blocks = ScheduleWeekLayout.calculate(
      selected: selected,
      available: selected,
      shift: 'auto',
    ).blocks;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const timeWidth = 128.0;
          final dayWidth = (constraints.maxWidth - timeWidth) / days.length;
          final heights = _rowHeights(blocks, dayWidth);
          final offsets = <double>[0];
          for (final height in heights) {
            offsets.add(offsets.last + height);
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _heading('HORÁRIO', timeWidth, time: true),
                  for (final day in days) _heading(day.toUpperCase(), dayWidth),
                ],
              ),
              SizedBox(
                height: offsets.last,
                child: Stack(
                  children: [
                    for (var i = 0; i < blocks.length; i++)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: offsets[i],
                        height: heights[i],
                        child: Container(
                          decoration: BoxDecoration(
                            color: i.isEven
                                ? Colors.white
                                : const Color(0xfffcfdff),
                            border: const Border(
                              top: BorderSide(color: _border),
                            ),
                          ),
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: timeWidth,
                            height: heights[i],
                            color: const Color(0xfff8fafc),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${scheduleTimeLabel(blocks[i].$1)} - ${scheduleTimeLabel(blocks[i].$2)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  switch (scheduleShiftOf(blocks[i].$1)) {
                                    'manha' => 'Manhã',
                                    'tarde' => 'Tarde',
                                    _ => 'Noite',
                                  },
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xff94a3b8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    for (var i = 0; i < days.length; i++)
                      Positioned(
                        left: timeWidth + i * dayWidth,
                        top: 0,
                        bottom: 0,
                        child: Container(width: 1, color: _border),
                      ),
                    for (final offering in selected)
                      for (final session in offering.sessions)
                        if (isTimetabledSession(session) &&
                            blocks.any((b) => b.$1 == session.startMinutes))
                          _session(
                            offering,
                            session,
                            blocks,
                            offsets,
                            timeWidth,
                            dayWidth,
                          ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<double> _rowHeights(List<(int, int)> blocks, double dayWidth) {
    final heights = [
      for (final block in blocks)
        scheduleShiftOf(block.$1) == 'noite' ? 116.0 : 88.0,
    ];
    // Match the card's margins, borders and padding before measuring wrapping.
    final textWidth = dayWidth - 12 - 2 - 3.5 - 20;
    for (final offering in selected) {
      for (final session in offering.sessions.where(isTimetabledSession)) {
        final rows = [
          for (var i = 0; i < blocks.length; i++)
            if (blocks[i].$1 >= session.startMinutes! &&
                blocks[i].$2 <= session.endMinutes!)
              i,
        ];
        if (rows.isEmpty) continue;
        var contentHeight = _textHeight(
          offering.name.toUpperCase(),
          _titleStyle,
          textWidth,
        );
        if (offering.code?.trim().isNotEmpty == true) {
          contentHeight +=
              _textHeight(
                offering.code!,
                const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
                textWidth - 10,
              ) +
              6 +
              5;
        }
        if (offering.professor?.trim().isNotEmpty == true) {
          contentHeight +=
              _textHeight(offering.professor!, _professorStyle, textWidth) + 5;
        }
        // Reserve a complete footer line and a small rounding allowance.
        final requiredHeight = contentHeight + 34 + 4 + 24 + 4;
        final availableHeight = rows.fold<double>(
          0,
          (sum, i) => sum + heights[i],
        );
        if (requiredHeight > availableHeight) {
          final extra = ((requiredHeight - availableHeight) / rows.length)
              .ceilToDouble();
          for (final i in rows) {
            heights[i] += extra;
          }
        }
      }
    }
    return heights;
  }

  double _textHeight(String text, TextStyle style, double width) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    final height = painter.height.ceilToDouble();
    painter.dispose();
    return height;
  }

  Widget _heading(String title, double width, {bool time = false}) => Container(
    width: width,
    height: 42,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: time ? const Color(0xfff1f5f9) : const Color(0xfff8fafc),
      border: const Border(right: BorderSide(color: _border)),
    ),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: .5,
      ),
    ),
  );

  Widget _session(
    Discipline offering,
    Session session,
    List<(int, int)> blocks,
    List<double> offsets,
    double timeWidth,
    double dayWidth,
  ) {
    final start = blocks.indexWhere((b) => b.$1 == session.startMinutes);
    final span = blocks
        .where(
          (b) => b.$1 >= session.startMinutes! && b.$2 <= session.endMinutes!,
        )
        .length;
    return Positioned(
      key: ValueKey(
        'export-session-${offering.id}-${session.day}-${session.time}',
      ),
      left: timeWidth + (session.day - 1) * dayWidth + 6,
      width: dayWidth - 12,
      top: offsets[start] + 6,
      height: offsets[start + span] - offsets[start] - 12,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xfff0f2ff),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xffdbe1ff)),
        ),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: _indigo, width: 3.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 5,
                  children: [
                    if (offering.code?.trim().isNotEmpty == true)
                      _badge(offering.code!),
                    Text(offering.name.toUpperCase(), style: _titleStyle),
                    if (offering.professor?.trim().isNotEmpty == true)
                      Text(offering.professor!, style: _professorStyle),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${scheduleTimeLabel(session.startMinutes!)} - ${scheduleTimeLabel(session.endMinutes!)}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _indigo,
                      ),
                    ),
                  ),
                  if (span > 1) _badge('$span aulas', fontSize: 9),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _unassigned() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xfffffbeb),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xfffde68a)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DISCIPLINAS SEM HORÁRIO DEFINIDO',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xff92400e),
          ),
        ),
        for (final offering in selected.where(
          (d) => !d.sessions.any(isTimetabledSession),
        ))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${offering.name}${offering.professor?.isNotEmpty == true ? ' • ${offering.professor}' : ''}',
            ),
          ),
      ],
    ),
  );
}
