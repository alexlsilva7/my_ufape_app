import 'package:flutter/material.dart';

import '../../../../core/models.dart';
import '../../widgets/academic_common.dart';
import '../../widgets/academic_motion.dart';
import '../../widgets/academic_palette.dart';
import '../../widgets/academic_context_menu.dart';
import 'badge.dart';
import 'week_layout.dart';

class ScheduleOfferingCard extends StatelessWidget {
  const ScheduleOfferingCard({
    super.key,
    required this.offering,
    required this.selected,
    required this.completed,
    required this.conflict,
    required this.onToggle,
    required this.onCompleted,
    required this.onDetails,
    this.disableMotion = false,
  });
  final Discipline offering;
  final bool selected, completed, disableMotion;
  final Discipline? conflict;
  final VoidCallback onToggle, onCompleted, onDetails;
  @override
  Widget build(BuildContext context) {
    final palette = AcademicPalette.of(context);
    final dark = palette.dark;
    Duration motion([int ms = 240]) =>
        academicMotionDuration(context, ms, disabled: disableMotion);
    final color = completed
        ? (dark ? const Color(0xff6ee7b7) : const Color(0xff047857))
        : selected
        ? palette.indigo
        : palette.ink;
    final fill = completed
        ? (dark ? const Color(0xff022c22) : const Color(0xfff0fdf9))
        : selected
        ? (dark ? const Color(0xff1e1b4b) : const Color(0xffeef2ff))
        : palette.surface;
    final card = AnimatedContainer(
      duration: motion(200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        animationDuration: motion(200),
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected
                ? palette.indigo.withAlpha(dark ? 80 : 40)
                : completed
                ? (dark ? const Color(0xff065f46) : const Color(0xffa7f3d0))
                : conflict != null
                ? const Color(0xfffbbf24)
                : palette.border,
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: completed ? null : onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          offering.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            height: 1.4,
                            color: color,
                            decoration: completed
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 144,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: completed
                                ? 'Marcar como pendente'
                                : 'Marcar como concluída',
                            onPressed: onCompleted,
                            icon: AcademicTransition(
                              identity: completed,
                              duration: motion(160),
                              child: Icon(
                                completed
                                    ? Icons.check_box_outlined
                                    : Icons.check_box_outline_blank,
                                size: 18,
                                color: completed ? color : palette.muted,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Detalhes e ementa',
                            onPressed: onDetails,
                            icon: Icon(
                              Icons.info_outline,
                              size: 18,
                              color: palette.muted,
                            ),
                          ),
                          IconButton(
                            tooltip: selected
                                ? 'Remover ${offering.name}'
                                : 'Adicionar ${offering.name}',
                            onPressed: completed ? null : onToggle,
                            icon: AcademicTransition(
                              identity: selected,
                              duration: motion(160),
                              child: Icon(
                                selected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                size: 18,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (completed)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      spacing: 4,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 13,
                          color: color,
                        ),
                        Text(
                          'CONCLUÍDA',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (conflict != null && !selected && !completed)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: AcademicChip(
                      'Conflito: ${conflict!.name}',
                      color: dark
                          ? const Color(0xfffcd34d)
                          : const Color(0xff92400e),
                      icon: Icons.warning_amber,
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  offering.professor?.isNotEmpty == true
                      ? offering.professor!
                      : 'Professor a confirmar',
                  style: TextStyle(fontSize: 11, color: color),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    ScheduleBadge(
                      offering.period == 0
                          ? 'OPT'
                          : offering.period == null
                          ? '—'
                          : '${offering.period}º',
                      background: selected
                          ? const Color(0xff4f46e5)
                          : completed
                          ? const Color(0xff047857)
                          : const Color(0xff1e293b),
                      disableMotion: disableMotion,
                      foreground: Colors.white,
                    ),
                    for (final session in offering.sessions)
                      ScheduleBadge(
                        '${session.day >= 1 && session.day <= 6 ? scheduleDays[session.day - 1].substring(0, 3).toUpperCase() : 'DIA'} ${session.time}',
                        background: dark
                            ? const Color(0xff1e293b)
                            : selected
                            ? const Color(0xffe0e7ff)
                            : const Color(0xfff1f5f9),
                        disableMotion: disableMotion,
                        foreground: color,
                      ),
                    if (offering.sessions.isEmpty)
                      ScheduleBadge(
                        'Horário não definido',
                        disableMotion: disableMotion,
                        foreground: palette.muted,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return KeyedSubtree(
      key: ValueKey('schedule-offering-${offering.id}'),
      child: AcademicContextMenu(
        actions: [
          AcademicMenuAction(
            'Detalhes e ementa',
            Icons.info_outline,
            onDetails,
          ),
          AcademicMenuAction(
            selected ? 'Remover da grade' : 'Adicionar à grade',
            selected ? Icons.remove_circle_outline : Icons.add_circle_outline,
            completed ? null : onToggle,
          ),
          AcademicMenuAction(
            completed ? 'Marcar como pendente' : 'Marcar como concluída',
            completed
                ? Icons.check_box_outlined
                : Icons.check_box_outline_blank,
            onCompleted,
            dividerBefore: true,
          ),
        ],
        child: motion() == Duration.zero
            ? card
            : AnimatedSize(
                duration: motion(200),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                child: card,
              ),
      ),
    );
  }
}
