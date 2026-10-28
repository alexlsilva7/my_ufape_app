import 'package:flutter/material.dart';

class SettingsThemeCard extends StatelessWidget {
  const SettingsThemeCard({
    super.key,
    required this.themeMode,
    required this.onCycleTheme,
  });
  final ThemeMode themeMode;
  final VoidCallback onCycleTheme;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.palette_outlined),
      title: const Text('Aparência'),
      subtitle: Text(switch (themeMode) {
        ThemeMode.system => 'Seguir o sistema',
        ThemeMode.light => 'Tema claro',
        ThemeMode.dark => 'Tema escuro',
      }),
      trailing: const Icon(Icons.chevron_right),
      onTap: onCycleTheme,
    ),
  );
}
