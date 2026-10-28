import 'package:flutter/material.dart';

import 'home_visuals.dart';

class HomeUtilityButton extends StatelessWidget {
  const HomeUtilityButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 48,
    height: 48,
    child: Material(
      color: homeSurface(context),
      shape: CircleBorder(side: BorderSide(color: homeBorder(context))),
      child: IconButton(
        tooltip: label,
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: const Color(0xff64748b)),
      ),
    ),
  );
}

class HomeUtilities extends StatelessWidget {
  const HomeUtilities({
    super.key,
    required this.themeMode,
    required this.onSettings,
    required this.onTheme,
    required this.onAdmin,
  });
  final ThemeMode themeMode;
  final VoidCallback onSettings;
  final VoidCallback onTheme;
  final VoidCallback onAdmin;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 8,
    children: [
      HomeUtilityButton(
        icon: Icons.settings_outlined,
        label: 'Backups e preferências',
        onTap: onSettings,
      ),
      HomeUtilityButton(
        icon: switch (themeMode) {
          ThemeMode.light => Icons.light_mode_outlined,
          ThemeMode.dark => Icons.dark_mode_outlined,
          ThemeMode.system => Icons.desktop_windows_outlined,
        },
        label: 'Alternar tema: ${themeMode.name}',
        onTap: onTheme,
      ),
      HomeUtilityButton(
        icon: Icons.admin_panel_settings_outlined,
        label: 'Administração',
        onTap: onAdmin,
      ),
    ],
  );
}
