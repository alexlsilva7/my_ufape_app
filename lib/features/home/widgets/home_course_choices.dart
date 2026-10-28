import 'package:flutter/material.dart';

import 'home_visuals.dart';
import '../../../core/models.dart';

class HomeCourseChoices extends StatelessWidget {
  const HomeCourseChoices({
    super.key,
    required this.courses,
    required this.loading,
    required this.muted,
    required this.onSelectCourse,
  });
  final List<CourseMeta> courses;
  final bool loading;
  final Color muted;
  final ValueChanged<CourseMeta?> onSelectCourse;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final visibleCourses = courses.where((c) => !c.hidden).toList();
      final columns =
          constraints.maxWidth >= 560 &&
              MediaQuery.textScalerOf(context).scale(14) <= 21
          ? 2
          : 1;
      if (visibleCourses.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            loading
                ? 'Carregando cursos…'
                : 'Nenhum curso disponível no momento.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted),
          ),
        );
      }
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final course in visibleCourses)
            SizedBox(
              width: (constraints.maxWidth - 12 * (columns - 1)) / columns,
              child: HomeButton(
                accent: homeIndigo,
                radius: 12,
                onTap: () => onSelectCourse(course),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Flex(
                    mainAxisSize: MainAxisSize.min,
                    direction: MediaQuery.textScalerOf(context).scale(14) > 21
                        ? Axis.vertical
                        : Axis.horizontal,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 12,
                    children: [
                      Flexible(
                        fit: FlexFit.loose,
                        child: Text(
                          course.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: (constraints.maxWidth * .28).clamp(48, 100),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: muted.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            course.shortName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10, color: muted),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
