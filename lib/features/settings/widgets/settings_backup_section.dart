import 'package:flutter/material.dart';

import '../../../services/files.dart';
import '../settings_view_model.dart';

class SettingsBackupSection extends StatelessWidget {
  const SettingsBackupSection({super.key, required this.viewModel});

  final SettingsViewModel viewModel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Backup e restauração',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      const Text(
        'Os arquivos são compatíveis com o backup do site. Contas e credenciais ficam fora do backup.',
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton.icon(
            onPressed: () => _run(context, () async {
              await saveJson('my_ufape_backup.json', viewModel.exportBackup());
            }),
            icon: const Icon(Icons.download),
            label: const Text('Exportar backup'),
          ),
          OutlinedButton.icon(
            onPressed: () => _run(context, () async {
              final data = await importJson();
              if (data == null || !context.mounted) return;
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Restaurar backup?'),
                  content: const Text(
                    'As preferências e os dados pessoais presentes no arquivo substituirão os valores deste dispositivo.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Restaurar'),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              final restored = await viewModel.importBackup(data);
              if (!restored) {
                throw const FormatException(
                  'Backup inválido ou sem dados reconhecidos.',
                );
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Backup restaurado.')),
                );
              }
            }),
            icon: const Icon(Icons.upload),
            label: const Text('Importar backup'),
          ),
        ],
      ),
    ],
  );

  Future<void> _run(BuildContext context, Future<void> Function() task) async {
    try {
      await task();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}
