import 'package:flutter/material.dart';

import 'home_visuals.dart';
import '../../../core/models.dart';
import 'home_course_choices.dart';
import 'home_features.dart';

class HomeCoursePanel extends StatelessWidget {
  const HomeCoursePanel({
    super.key,
    required this.course,
    required this.courses,
    required this.loading,
    required this.muted,
    required this.onSelectCourse,
    required this.onNavigate,
  });
  final CourseMeta? course;
  final List<CourseMeta> courses;
  final bool loading;
  final Color muted;
  final ValueChanged<CourseMeta?> onSelectCourse;
  final ValueChanged<String> onNavigate;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final padding = constraints.maxWidth >= 640 ? 32.0 : 16.0;
      return HomePanel(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flex(
              mainAxisSize: MainAxisSize.min,
              direction: MediaQuery.textScalerOf(context).scale(14) > 21
                  ? Axis.vertical
                  : Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                const HomeIconTile(
                  kind: HomeLineIcon.book,
                  color: homeIndigo,
                  size: 40,
                ),
                Flexible(
                  flex: 1,
                  fit: FlexFit.loose,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text(
                        course?.name ?? 'Selecione seu curso',
                        style: TextStyle(
                          fontSize: constraints.maxWidth < 600 ? 18 : 20,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (course == null)
                        Text(
                          'Escolha seu curso para ver o horário letivo e matriz.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: muted,
                          ),
                        )
                      else
                        HomeTextLink(
                          'Alterar curso',
                          onTap: () => onSelectCourse(null),
                          color: const Color(0xff6366f1),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(
              height: constraints.maxWidth < 600
                  ? 16
                  : course == null
                  ? 24
                  : 32,
            ),
            if (course == null)
              HomeCourseChoices(
                courses: courses,
                loading: loading,
                muted: muted,
                onSelectCourse: onSelectCourse,
              )
            else ...[
              HomeFeatures(
                course: course!,
                muted: muted,
                onNavigate: onNavigate,
              ),
            ],
          ],
        ),
      );
    },
  );
}
