import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/data_source.dart';
import '../../services/files.dart';

class SettingsScreen extends StatelessWidget {
  final AppState state;
  const SettingsScreen({super.key, required this.state});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) => _page(context),
  );
  Widget _page(BuildContext context) => ListView(
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
              Card(
                child: ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Aparência'),
                  subtitle: Text(switch (state.themeMode) {
                    ThemeMode.system => 'Seguir o sistema',
                    ThemeMode.light => 'Tema claro',
                    ThemeMode.dark => 'Tema escuro',
                  }),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: state.cycleTheme,
                ),
              ),
              const SizedBox(height: 16),
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
                      await saveJson(
                        'my_ufape_backup.json',
                        state.exportBackup(),
                      );
                    }),
                    icon: const Icon(Icons.download),
                    label: const Text('Exportar backup'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _run(context, () async {
                      final data = await importJson();
                      if (data == null) return;
                      if (!context.mounted) return;
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Restaurar backup?'),
                          content: const Text(
                            'As preferências e os dados pessoais presentes no arquivo substituirão os valores deste dispositivo.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Restaurar'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                      final restored = await state.importBackup(data);
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
              const SizedBox(height: 32),
              Text(
                'Fonte dos dados',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              SelectableText(state.dataSourceLabel),
              if (state.repositories.source == DataSource.api)
                TextButton.icon(
                  onPressed: () => _editServer(context),
                  icon: const Icon(Icons.dns_outlined),
                  label: const Text('Alterar servidor'),
                ),
              const SizedBox(height: 8),
              Text(
                state.repositories.isLocal
                    ? 'Os dados são lidos dos JSONs incluídos. Alterações ficam salvas neste dispositivo, sem conexão com um servidor.'
                    : 'Os dados publicados vêm da fonte configurada. Sem conexão, o aplicativo consulta o cache ou a cópia local incluída.',
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _run(context, () => state.refresh()),
                icon: const Icon(Icons.refresh),
                label: const Text('Atualizar dados'),
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
    final input = TextEditingController(text: state.apiBaseUrl);
    final route = DialogRoute<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Servidor My UFAPE'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              const Text(
                'Informe o endereço da instalação My UFAPE que fornece os cursos e os dados publicados.',
              ),
              TextField(
                controller: input,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Endereço HTTPS',
                  hintText: 'https://meu-servidor.exemplo',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, input.text.trim()),
            child: const Text('Conectar'),
          ),
        ],
      ),
    );
    final value = await Navigator.of(context).push(route);
    await route.completed;
    input.dispose();
    if (value != null && context.mounted) {
      await _run(context, () => state.setApiBaseUrl(value));
    }
  }
}
