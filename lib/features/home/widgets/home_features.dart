import 'package:flutter/material.dart';

import 'home_visuals.dart';
import '../../../core/models.dart';
import 'home_navigation_card.dart';

class HomeFeatures extends StatelessWidget {
  const HomeFeatures({
    super.key,
    required this.course,
    required this.muted,
    required this.onNavigate,
  });
  final CourseMeta course;
  final Color muted;
  final ValueChanged<String> onNavigate;
  @override
  Widget build(BuildContext context) {
    final features = [
      if (course.hasSchedule && course.showSchedule)
        (
          HomeLineIcon.calendar,
          homeIndigo,
          'Horário Letivo',
          'Monte sua grade horária personalizada com as turmas ofertadas este semestre.',
          'Montar Grade',
          '/schedule',
        ),
      if (course.hasCurriculum && course.showDisciplines)
        (
          HomeLineIcon.book,
          homeEmerald,
          'Disciplinas',
          'Consulte a lista completa de disciplinas, ementas e pré-requisitos do curso.',
          'Consultar Catálogo',
          '/disciplinas',
        ),
      if (course.hasCurriculum && course.showMatriz)
        (
          HomeLineIcon.layers,
          homeViolet,
          'Matriz Curricular',
          'Visualize a estrutura curricular de forma organizada por períodos letivos.',
          'Visualizar Grade',
          '/matriz',
        ),
    ];
    if (features.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Nenhum módulo está disponível para este curso no momento.',
          style: TextStyle(color: muted),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720 &&
            MediaQuery.textScalerOf(context).scale(14) <= 21) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 24,
              children: [
                for (var i = 0; i < features.length; i++)
                  Expanded(
                    child: HomeFeatureCard(
                      feature: features[i],
                      compact: false,
                      muted: muted,
                      onNavigate: onNavigate,
                    ),
                  ),
              ],
            ),
          );
        }
        return Column(
          spacing: 12,
          children: [
            for (var i = 0; i < features.length; i++)
              SizedBox(
                width: double.infinity,
                child: HomeFeatureCard(
                  feature: features[i],
                  compact: true,
                  muted: muted,
                  onNavigate: onNavigate,
                ),
              ),
          ],
        );
      },
    );
  }
}

class HomeFeatureCard extends StatelessWidget {
  const HomeFeatureCard({
    super.key,
    required this.feature,
    required this.compact,
    required this.muted,
    required this.onNavigate,
  });
  final (HomeLineIcon, Color, String, String, String, String) feature;
  final bool compact;
  final Color muted;
  final ValueChanged<String> onNavigate;
  @override
  Widget build(BuildContext context) {
    final (icon, color, title, description, action, path) = feature;
    if (compact) {
      return HomeNavigationCard(
        muted: muted,
        onNavigate: onNavigate,
        icon: icon,
        color: color,
        title: title,
        description: description,
        action: action,
        path: path,
      );
    }
    final foreground = Theme.of(context).brightness == Brightness.dark
        ? Color.lerp(color, Colors.white, .4)!
        : color;
    return HomeButton(
      accent: color,
      onTap: () => onNavigate(path),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 256),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HomeIconTile(kind: icon, color: color),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.55,
                      letterSpacing: -.45,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(fontSize: 14, height: 1.625, color: muted),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Row(
                  spacing: 4,
                  children: [
                    Flexible(
                      child: Text(
                        action,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: foreground,
                        ),
                      ),
                    ),
                    HomeStrokeIcon(
                      HomeLineIcon.arrow,
                      color: foreground,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
