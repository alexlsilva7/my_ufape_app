import 'package:flutter/material.dart';

import '../../widgets/academic_motion.dart';
import '../../widgets/academic_palette.dart';

class SchedulePeriodFilter extends StatefulWidget {
  const SchedulePeriodFilter({
    super.key,
    required this.periods,
    required this.hasElectives,
    required this.selectedPeriod,
    required this.onChanged,
  });
  final List<int> periods;
  final bool hasElectives;
  final int? selectedPeriod;
  final ValueChanged<int?> onChanged;
  @override
  State<SchedulePeriodFilter> createState() => _SchedulePeriodFilterState();
}

class _SchedulePeriodFilterState extends State<SchedulePeriodFilter> {
  final _periodScroll = ScrollController();
  @override
  void dispose() {
    _periodScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AcademicPalette.of(context).canvas,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Períodos anteriores',
          onPressed: () => _scrollPeriods(-1),
          icon: Icon(
            Icons.chevron_left,
            size: 18,
            color: AcademicPalette.of(context).muted,
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => Scrollbar(
              key: const ValueKey('schedule-period-scrollbar'),
              controller: _periodScroll,
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                controller: _periodScroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    for (final period in <int?>[
                      null,
                      ...widget.periods,
                      if (widget.hasElectives) 0,
                    ])
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                        ),
                        child: SchedulePeriodButton(
                          period: period,
                          selectedPeriod: widget.selectedPeriod,
                          onChanged: widget.onChanged,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Próximos períodos',
          onPressed: () => _scrollPeriods(1),
          icon: Icon(
            Icons.chevron_right,
            size: 18,
            color: AcademicPalette.of(context).muted,
          ),
        ),
      ],
    ),
  );

  void _scrollPeriods(int direction) {
    if (!_periodScroll.hasClients) return;
    final position = _periodScroll.position;
    final target =
        (position.pixels + direction * position.viewportDimension * .8).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
    final duration = academicMotionDuration(context, 200);
    if (duration == Duration.zero) {
      _periodScroll.jumpTo(target);
    } else {
      _periodScroll.animateTo(
        target,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
    }
  }
}

class SchedulePeriodButton extends StatelessWidget {
  const SchedulePeriodButton({
    super.key,
    required this.period,
    required this.selectedPeriod,
    required this.onChanged,
  });
  final int? period;
  final int? selectedPeriod;
  final ValueChanged<int?> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(4),
    child: TextButton(
      key: ValueKey('schedule-period-$period'),
      onPressed: () => onChanged(period),
      style: TextButton.styleFrom(
        animationDuration: academicMotionDuration(context, 180),
        minimumSize: const Size(48, 48),
        backgroundColor: selectedPeriod == period
            ? AcademicPalette.of(context).surface
            : Colors.transparent,
        foregroundColor: selectedPeriod == period
            ? AcademicPalette.of(context).ink
            : AcademicPalette.of(context).muted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Text(
        period == null
            ? 'Todos'
            : period == 0
            ? 'Optativas'
            : '$periodº',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
