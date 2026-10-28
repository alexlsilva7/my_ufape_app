import 'package:flutter/material.dart';

import 'settings_view_model.dart';
import 'widgets/settings_backup_section.dart';
import 'widgets/settings_theme_card.dart';
import 'widgets/settings_data_source_section.dart';
import 'widgets/settings_server_dialog.dart';

class SettingsView extends StatelessWidget {
  final SettingsViewModel viewModel;
  const SettingsView({super.key, required this.viewModel});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Do seu jeito',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Suas preferências, horário e progresso ficam neste dispositivo.',
                ),
                const SizedBox(height: 24),
                SettingsThemeCard(
                  themeMode: viewModel.themeMode,
                  onCycleTheme: viewModel.cycleTheme,
                ),
                const SizedBox(height: 16),
                SettingsBackupSection(viewModel: viewModel),
                const SizedBox(height: 32),
                SettingsDataSourceSection(
                  dataSourceLabel: viewModel.dataSourceLabel,
                  canEditServer: viewModel.canEditServer,
                  isLocal: viewModel.isLocal,
                  onEditServer: () => _editServer(context),
                  onRefresh: () => _run(context, viewModel.refresh),
                ),
                const SizedBox(height: 32),
                const Text(
                  'My UFAPE • Flutter e Dart • Código aberto',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
  Future<void> _run(BuildContext context, Future<void> Function() task) async {
    try {
      await task();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _editServer(BuildContext context) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => SettingsServerDialog(initialUrl: viewModel.apiBaseUrl),
    );
    if (value != null && context.mounted) {
      await _run(context, () => viewModel.setApiBaseUrl(value));
    }
  }
}
