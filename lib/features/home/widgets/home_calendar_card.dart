import 'package:flutter/material.dart';

import 'home_visuals.dart';
import 'home_navigation_card.dart';

class HomeCalendarCard extends StatelessWidget {
  const HomeCalendarCard({
    super.key,
    required this.muted,
    required this.onNavigate,
  });
  final Color muted;
  final ValueChanged<String> onNavigate;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        constraints.maxWidth < 600 ||
            MediaQuery.textScalerOf(context).scale(14) > 21
        ? HomeNavigationCard(
            muted: muted,
            onNavigate: onNavigate,
            icon: HomeLineIcon.calendar,
            color: homeIndigo,
            title: 'Calendário acadêmico',
            description: 'Consulte o mês atual e amplie as páginas do calendário oficial.',
            action: 'Abrir calendário',
            path: '/calendario',
          )
        : HomeDesktopCalendar(muted: muted, onNavigate: onNavigate),
  );
}

class HomeDesktopCalendar extends StatelessWidget {
  const HomeDesktopCalendar({
    super.key,
    required this.muted,
    required this.onNavigate,
  });
  final Color muted;
  final ValueChanged<String> onNavigate;
  @override
  Widget build(BuildContext context) => HomeButton(
    accent: homeIndigo,
    border: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xff312e81)
        : const Color(0xffc7d2fe),
    onTap: () => onNavigate('/calendario'),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        spacing: 16,
        children: [
          const HomeIconTile(kind: HomeLineIcon.calendar, color: homeIndigo),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                const Text(
                  'Calendário acadêmico',
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.55,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Consulte o mês atual e amplie as páginas do calendário oficial.',
                  style: TextStyle(fontSize: 14, height: 1.5, color: muted),
                ),
              ],
            ),
          ),
          const HomeStrokeIcon(
            HomeLineIcon.arrow,
            color: Color(0xff6366f1),
            size: 20,
          ),
        ],
      ),
    ),
  );
}
