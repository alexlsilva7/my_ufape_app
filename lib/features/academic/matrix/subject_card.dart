import 'package:flutter/material.dart';

import '../../../core/models.dart';
import '../academic_common.dart';
import '../academic_motion.dart';
import '../academic_palette.dart';
import '../academic_context_menu.dart';
import 'matrix_motion.dart';

class MatrixSubjectCard extends StatelessWidget {
  const MatrixSubjectCard({
    super.key,
    required this.subject,
    required this.status,
    required this.blocked,
    required this.highlightedId,
    required this.highlightedSubject,
    required this.onCycleStatus,
    required this.onDetails,
    required this.onEditElective,
    required this.onStatusChanged,
    this.comfortable = false,
  });
  final Subject subject;
  final String status;
  final bool blocked;
  final bool comfortable;
  final String? highlightedId;
  final Subject? highlightedSubject;
  final VoidCallback onCycleStatus, onDetails, onEditElective;
  final ValueChanged<String> onStatusChanged;
  @override
  Widget build(BuildContext context) {
    final palette = AcademicPalette.of(context);
    final dark = palette.dark;
    final color = palette.matrixStatusColor(status);
    final selected = highlightedSubject;
    Duration motion(int ms) => academicMotionDuration(context, ms);
    final active = highlightedId == subject.id;
    final prereq =
        selected?.prereqs.any(
          (ref) => ref == subject.id || ref == subject.code,
        ) ??
        false;
    final dependent =
        selected != null &&
        subject.prereqs.any(
          (ref) => ref == selected.id || ref == selected.code,
        );
    final related = active || prereq || dependent;
    final elective = subject.isGenericElective || subject.additionalElective;
    final border = prereq
        ? const Color(0xfffb7185)
        : dependent
        ? const Color(0xff14b8a6)
        : status == 'concluido'
        ? const Color(0xff34d399)
        : status == 'cursando'
        ? const Color(0xfffbbf24)
        : dark
        ? const Color(0xff334155)
        : const Color(0xffcbd5e1);
    final background = status == 'concluido'
        ? (dark ? const Color(0xff064e3b) : const Color(0xffe0faf0))
        : status == 'cursando'
        ? (dark ? const Color(0xff451a03) : const Color(0xfffffbeb))
        : dark
        ? const Color(0xff0f172a)
        : Colors.white;
    final details = onDetails;
    return AcademicContextMenu(
      actions: [
        AcademicMenuAction('Detalhes e nota', Icons.info_outline, details),
        for (final entry in statusNames.entries)
          AcademicMenuAction(
            'Marcar como ${entry.value.toLowerCase()}',
            entry.key == 'concluido'
                ? Icons.check_circle_outline
                : entry.key == 'cursando'
                ? Icons.timelapse
                : Icons.circle_outlined,
            () => onStatusChanged(entry.key),
            checked: status == entry.key,
            dividerBefore: entry.key == 'pendente',
          ),
        if (elective)
          AcademicMenuAction(
            subject.electiveSelection == null
                ? 'Definir optativa'
                : 'Editar optativa',
            Icons.edit_outlined,
            onEditElective,
            dividerBefore: true,
          ),
      ],
      child: MatrixCardFeedback(
        child: AnimatedOpacity(
          duration: motion(160),
          curve: Curves.easeOutCubic,
          opacity: selected != null && !related ? .4 : 1,
          child: AnimatedContainer(
            key: ValueKey('matrix-fill-${subject.id}'),
            duration: motion(200),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Material(
              key: ValueKey('matrix-subject-${subject.id}'),
              animationDuration: motion(200),
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: border, width: related ? 1.5 : 1),
              ),
              elevation: 1,
              shadowColor: Colors.black.withValues(alpha: .12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onCycleStatus,
                onLongPress: details,
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 24),
                            child: Text(
                              subject.displayName,
                              maxLines: comfortable ? 4 : 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: comfortable ? 14 : 12,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                                color: status == 'pendente'
                                    ? (dark
                                          ? const Color(0xffe2e8f0)
                                          : const Color(0xff334155))
                                    : color,
                              ),
                            ),
                          ),
                          if (subject.electiveSelection != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                subject.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: comfortable ? 11 : 10,
                                  color: palette.matrixStatusColor('pendente'),
                                ),
                              ),
                            ),
                          const Spacer(),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: dark
                                    ? const Color(0xff1e293b)
                                    : Colors.white.withValues(alpha: .8),
                                border: Border.all(
                                  color: dark
                                      ? const Color(0xff334155)
                                      : const Color(0xffe2e8f0),
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${hoursLabel(subject.displayHours)}h',
                                style: TextStyle(
                                  fontSize: comfortable ? 11 : 10,
                                  color: palette.matrixStatusColor('pendente'),
                                ),
                              ),
                            ),
                          ),
                          if (elective) ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: onEditElective,
                              icon: const Icon(Icons.edit_outlined, size: 13),
                              label: Text(
                                subject.electiveSelection == null
                                    ? 'Definir optativa'
                                    : 'Editar optativa',
                                style: TextStyle(
                                  fontSize: comfortable ? 12 : 10,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(48, 36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                foregroundColor: dark
                                    ? const Color(0xffc7d2fe)
                                    : const Color(0xff4f46e5),
                                backgroundColor: dark
                                    ? const Color(0xff1e1b4b)
                                    : const Color(0xffeef2ff),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        tooltip: 'Detalhes e nota',
                        onPressed: details,
                        icon: AcademicTransition(
                          identity: (status, blocked),
                          duration: motion(160),
                          child: Icon(
                            status == 'concluido'
                                ? Icons.check_circle_outline
                                : status == 'cursando'
                                ? Icons.circle
                                : blocked
                                ? Icons.warning_amber_rounded
                                : Icons.info_outline,
                            size: status == 'cursando' ? 12 : 17,
                            color: status == 'pendente'
                                ? (dark
                                      ? const Color(0xff94a3b8)
                                      : const Color(0xff94a3b8))
                                : color,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
