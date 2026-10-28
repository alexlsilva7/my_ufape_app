import 'package:flutter/material.dart';

class SettingsDataSourceSection extends StatelessWidget {
  const SettingsDataSourceSection({
    super.key,
    required this.dataSourceLabel,
    required this.canEditServer,
    required this.isLocal,
    required this.onEditServer,
    required this.onRefresh,
  });
  final String dataSourceLabel;
  final bool canEditServer;
  final bool isLocal;
  final VoidCallback onEditServer;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Fonte dos dados', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      SelectableText(dataSourceLabel),
      if (canEditServer)
        TextButton.icon(
          onPressed: onEditServer,
          icon: const Icon(Icons.dns_outlined),
          label: const Text('Alterar servidor'),
        ),
      const SizedBox(height: 8),
      Text(
        isLocal
            ? 'Os dados são lidos dos JSONs incluídos. Alterações ficam salvas neste dispositivo, sem conexão com um servidor.'
            : 'Os dados publicados vêm da fonte configurada. Sem conexão, o aplicativo consulta o cache ou a cópia local incluída.',
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh),
        label: const Text('Atualizar dados'),
      ),
    ],
  );
}
