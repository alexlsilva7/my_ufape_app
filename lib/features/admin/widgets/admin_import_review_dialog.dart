import 'package:flutter/material.dart';

import '../admin_view_model.dart';

class AdminImportReviewDialog extends StatelessWidget {
  const AdminImportReviewDialog({super.key, required this.preview});

  final AdminImportPreview preview;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Revisar ${preview.merge ? 'mesclagem' : 'substituição'}'),
    content: SizedBox(
      width: 780,
      height: 500,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Text(
              '${preview.changes.length} alterações · ${preview.errors.length} problemas',
            ),
            if (preview.errors.isNotEmpty)
              SelectableText(
                preview.errors.join('\n'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            SelectableText(
              preview.changes.isEmpty
                  ? 'Nenhuma alteração.'
                  : preview.changes.take(500).join('\n'),
            ),
            if (preview.changes.length > 500)
              const Text(
                'Prévia limitada a 500 linhas; exporte o JSON para a comparação completa.',
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: preview.canApply ? () => Navigator.pop(context, true) : null,
        child: const Text('Aplicar ao rascunho'),
      ),
    ],
  );
}
