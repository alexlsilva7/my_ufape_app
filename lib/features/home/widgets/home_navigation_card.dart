import 'package:flutter/material.dart';

import 'home_visuals.dart';

class HomeNavigationCard extends StatelessWidget {
  const HomeNavigationCard({
    super.key,
    required this.muted,
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.action,
    required this.path,
    required this.onNavigate,
  });
  final Color muted;
  final HomeLineIcon icon;
  final Color color;
  final String title;
  final String description;
  final String action;
  final String path;
  final ValueChanged<String> onNavigate;
  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).brightness == Brightness.dark
        ? Color.lerp(color, Colors.white, .4)!
        : color;
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          description,
          style: TextStyle(fontSize: 13, height: 1.5, color: muted),
        ),
        Row(
          spacing: 8,
          children: [
            Flexible(
              child: Text(
                action,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ),
            HomeStrokeIcon(HomeLineIcon.arrow, color: foreground, size: 16),
          ],
        ),
      ],
    );
    return HomeButton(
      key: ValueKey('home-link-$path'),
      accent: color,
      onTap: () => onNavigate(path),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: MediaQuery.textScalerOf(context).scale(14) > 21
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  HomeIconTile(kind: icon, color: color, size: 40),
                  body,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  HomeIconTile(kind: icon, color: color, size: 40),
                  Expanded(child: body),
                ],
              ),
      ),
    );
  }
}
