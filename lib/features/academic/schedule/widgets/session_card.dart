import 'package:flutter/material.dart';

import '../../../../core/models.dart';
import '../../widgets/academic_motion.dart';
import '../../widgets/academic_palette.dart';
import '../../widgets/academic_context_menu.dart';
import 'badge.dart';

class ScheduleSessionCard extends StatelessWidget {
  const ScheduleSessionCard({
    super.key,
    required this.offering,
    required this.session,
    required this.span,
    required this.dayWidth,
    required this.onDetails,
    required this.onRemove,
    this.onCompleted,
    this.disableMotion = false,
  });
  final Discipline offering;
  final Session session;
  final int span;
  final double dayWidth;
  final bool disableMotion;
  final VoidCallback onDetails, onRemove;
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context) {
    final palette = AcademicPalette.of(context);
    final color = palette.indigo;
    final code = offering.code?.trim() ?? '';
    final professor = offering.professor?.trim() ?? '';
    return AcademicContextMenu(
      actions: [
        AcademicMenuAction('Detalhes e ementa', Icons.info_outline, onDetails),
        AcademicMenuAction(
          'Remover da grade',
          Icons.remove_circle_outline,
          onRemove,
        ),
        if (onCompleted != null)
          AcademicMenuAction(
            'Marcar como concluída',
            Icons.check_box_outline_blank,
            onCompleted,
            dividerBefore: true,
          ),
      ],
      child: Material(
        animationDuration: academicMotionDuration(
          context,
          200,
          disabled: disableMotion,
        ),
        color: palette.dark ? const Color(0xff1e1b4b) : const Color(0xffeef2ff),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: palette.dark
                ? const Color(0xff312e81)
                : const Color(0xffe0e7ff),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onDetails(),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: Color(0xff4f46e5), width: 3.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 5,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              if (code.isNotEmpty)
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: ScheduleBadge(
                                    code,
                                    background: palette.dark
                                        ? const Color(0xff312e81)
                                        : const Color(0xffe0e7ff),
                                    disableMotion: disableMotion,
                                    foreground: color,
                                  ),
                                ),
                              TextSpan(
                                text:
                                    '${code.isNotEmpty ? ' ' : ''}${offering.name.toUpperCase()}',
                              ),
                            ],
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            color: palette.dark
                                ? const Color(0xffe0e7ff)
                                : const Color(0xff1e1b4b),
                          ),
                        ),
                        Text(
                          professor.isEmpty
                              ? 'Professor a confirmar'
                              : professor,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: palette.dark
                                ? const Color(0xffc7d2fe)
                                : const Color(0xff3730a3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (span > 1 && dayWidth < 180)
                  Align(
                    alignment: Alignment.centerRight,
                    child: ScheduleBadge(
                      '$span aulas',
                      background: palette.dark
                          ? const Color(0xff312e81)
                          : const Color(0xffe0e7ff),
                      disableMotion: disableMotion,
                      foreground: color,
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        session.time,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                    if (span > 1 && dayWidth >= 180)
                      ScheduleBadge(
                        '$span aulas',
                        background: palette.dark
                            ? const Color(0xff312e81)
                            : const Color(0xffe0e7ff),
                        disableMotion: disableMotion,
                        foreground: color,
                      ),
                    IconButton(
                      tooltip: 'Remover ${offering.name}',
                      onPressed: () => onRemove(),
                      icon: Icon(Icons.close, size: 16, color: color),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
