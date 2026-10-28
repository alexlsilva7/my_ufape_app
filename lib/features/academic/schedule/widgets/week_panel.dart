import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/models.dart';
import '../../widgets/academic_motion.dart';
import '../../widgets/academic_palette.dart';
import 'badge.dart';
import 'week_grid.dart';
import 'unassigned_offerings.dart';

class ScheduleWeekPanel extends StatelessWidget {
  const ScheduleWeekPanel({
    super.key,
    required this.selected,
    required this.available,
    required this.scope,
    required this.courseName,
    required this.semester,
    required this.shift,
    required this.exporting,
    required this.onShiftChanged,
    required this.onExport,
    required this.onHelp,
    required this.onClear,
    required this.onDetails,
    required this.onToggle,
    required this.onCompleted,
  });
  final List<Discipline> selected;
  final List<Discipline> available;
  final Object scope;
  final String courseName;
  final String semester;
  final String shift;
  final bool exporting;
  final ValueChanged<String> onShiftChanged;
  final VoidCallback onExport;
  final VoidCallback onHelp;
  final VoidCallback onClear;
  final ValueChanged<Discipline> onDetails;
  final ValueChanged<Discipline> onToggle;
  final ValueChanged<Discipline> onCompleted;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: AcademicPalette.of(context).surface,
          border: Border(
            bottom: BorderSide(color: AcademicPalette.of(context).border),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Sua Grade',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AcademicPalette.of(context).ink,
                    ),
                  ),
                  AcademicTransition(
                    identity: selected.length,
                    duration: academicMotionDuration(
                      context,
                      180,
                      disabled: exporting,
                    ),
                    child: ScheduleBadge(
                      '${selected.length} ${selected.length == 1 ? 'disciplina' : 'disciplinas'}',
                      disableMotion: exporting,
                      foreground: AcademicPalette.of(context).muted,
                    ),
                  ),
                  SizedBox(
                    width: math.min(390, constraints.maxWidth),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AcademicPalette.of(context).canvas,
                          border: Border.all(
                            color: AcademicPalette.of(context).border,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            for (final entry in const {
                              'auto': 'Automático',
                              'manha': 'Manhã',
                              'tarde': 'Tarde',
                              'noite': 'Noite',
                              'all': 'Todos',
                            }.entries)
                              TextButton(
                                key: ValueKey('schedule-shift-${entry.key}'),
                                onPressed: () => onShiftChanged(entry.key),
                                style: TextButton.styleFrom(
                                  animationDuration: academicMotionDuration(
                                    context,
                                    180,
                                    disabled: exporting,
                                  ),
                                  minimumSize: const Size(48, 48),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  foregroundColor: shift == entry.key
                                      ? AcademicPalette.of(context).indigo
                                      : AcademicPalette.of(context).muted,
                                  backgroundColor: shift == entry.key
                                      ? AcademicPalette.of(context).surface
                                      : Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: Text(
                                  entry.value,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: exporting || selected.isEmpty ? null : onExport,
                    icon: exporting
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_camera_outlined, size: 16),
                    label: const Text('Salvar imagem'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onHelp,
                    icon: const Icon(Icons.help_outline, size: 16),
                    label: const Text('Como usar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AcademicPalette.of(context).indigo,
                    ),
                  ),
                  if (selected.isNotEmpty)
                    IconButton(
                      tooltip: 'Limpar grade',
                      onPressed: onClear,
                      icon: const Icon(Icons.delete_outline, size: 20),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final gridWidth = math.max(constraints.maxWidth - 40, 900.0);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: RepaintBoundary(
                  child: ColoredBox(
                    color: AcademicPalette.of(context).canvas,
                    child: SizedBox(
                      width: gridWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: AcademicPalette.of(context).surface,
                              border: Border.all(
                                color: AcademicPalette.of(context).border,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: .04),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: ScheduleWeekGrid(
                              selected: selected,
                              available: available,
                              shift: shift,
                              scope: scope,
                              availableHeight: constraints.maxHeight - 40,
                              onDetails: onDetails,
                              onToggle: onToggle,
                              onCompleted: onCompleted,
                              disableMotion: exporting,
                            ),
                          ),
                          ScheduleUnassignedOfferings(
                            selected: selected,
                            onDetails: onDetails,
                            onToggle: onToggle,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              '$courseName • $semester • Horários sujeitos a alterações oficiais',
                              style: TextStyle(
                                fontSize: 10,
                                color: AcademicPalette.of(context).muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}
