import 'package:flutter/material.dart';

import '../../../data/parsers/admin_data.dart';
import 'admin_section.dart';

import 'package:flutter/services.dart';

class AdminImportSection extends StatelessWidget {
  const AdminImportSection({
    super.key,
    required this.importTarget,
    required this.extractMode,
    required this.supportsExtraction,
    required this.busy,
    required this.extracting,
    required this.pasteController,
    required this.modelController,
    required this.sourceTextController,
    required this.resumeController,
    required this.files,
    required this.monitorError,
    required this.snapshot,
    required this.extracted,
    required this.onTargetChanged,
    required this.onModeChanged,
    required this.onOpenJson,
    required this.onReviewJson,
    required this.onExport,
    required this.onEditPipeline,
    required this.onPickSources,
    required this.onStart,
    required this.onRemoveFile,
    required this.onResumeChanged,
    required this.onResume,
    required this.onReviewResult,
    required this.onDownloadResult,
  });
  final String importTarget;
  final String extractMode;
  final bool supportsExtraction;
  final bool busy;
  final bool extracting;
  final TextEditingController pasteController;
  final TextEditingController modelController;
  final TextEditingController sourceTextController;
  final TextEditingController resumeController;
  final List<Json> files;
  final String monitorError;
  final Json? snapshot;
  final Json? extracted;
  final ValueChanged<String> onTargetChanged;
  final ValueChanged<String> onModeChanged;
  final VoidCallback onOpenJson;
  final ValueChanged<bool> onReviewJson;
  final VoidCallback onExport;
  final VoidCallback onEditPipeline;
  final VoidCallback onPickSources;
  final VoidCallback onStart;
  final ValueChanged<Json> onRemoveFile;
  final VoidCallback onResumeChanged;
  final VoidCallback onResume;
  final VoidCallback onReviewResult;
  final VoidCallback onDownloadResult;
  @override
  Widget build(
    BuildContext context,
  ) => AdminSectionPage('Importação e extração', [
    AdminPanel('JSON acadêmico', [
      DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: importTarget,
        decoration: const InputDecoration(labelText: 'Destino'),
        items: const [
          DropdownMenuItem(
            value: 'curriculum',
            child: Text('Currículo, perfis e estrutura'),
          ),
          DropdownMenuItem(value: 'schedule', child: Text('Oferta semestral')),
        ],
        onChanged: (value) {
          if (value != null) onTargetChanged(value);
        },
      ),
      TextField(
        controller: pasteController,
        minLines: 5,
        maxLines: 12,
        decoration: const InputDecoration(labelText: 'Cole o JSON'),
      ),
      Wrap(
        spacing: 12,
        runSpacing: 10,
        children: [
          OutlinedButton.icon(
            onPressed: onOpenJson,
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('Abrir JSON'),
          ),
          for (final merge in [false, true])
            FilledButton.tonal(
              onPressed: busy ? null : () => onReviewJson(merge),
              child: Text(merge ? 'Revisar mesclagem' : 'Revisar substituição'),
            ),
          OutlinedButton.icon(
            onPressed: onExport,
            icon: const Icon(Icons.download),
            label: const Text('Exportar rascunho'),
          ),
        ],
      ),
    ]),
    if (!supportsExtraction)
      const Text(
        'Neste modo, importe os dados pelo JSON acima. Extração por IA exige o serviço remoto no modo API.',
      ),
    if (supportsExtraction)
      AdminPanel('Extrair PDF, imagem ou texto com IA', [
        const Text(
          'A extração usa o backend existente. O resultado sempre passa por revisão e não é publicado automaticamente.',
        ),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: extractMode,
          decoration: const InputDecoration(labelText: 'Tipo de extração'),
          items: const [
            DropdownMenuItem(
              value: 'tree',
              child: Text('Matriz / estrutura curricular'),
            ),
            DropdownMenuItem(
              value: 'linear',
              child: Text('Catálogo e ementas'),
            ),
            DropdownMenuItem(
              value: 'schedule',
              child: Text('Horários letivos'),
            ),
          ],
          onChanged: extracting
              ? null
              : (value) {
                  if (value != null) onModeChanged(value);
                },
        ),
        OutlinedButton(
          onPressed: extracting ? null : onEditPipeline,
          child: const Text('Configurar etapas e concorrência'),
        ),
        TextField(
          controller: modelController,
          enabled: !extracting,
          decoration: const InputDecoration(
            labelText: 'Modelo (opcional)',
            helperText:
                'Vazio usa o provedor e o modelo configurados no servidor.',
          ),
        ),
        TextField(
          controller: sourceTextController,
          enabled: !extracting,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Texto do documento (opcional)',
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: extracting ? null : onPickSources,
              icon: const Icon(Icons.attach_file),
              label: const Text('Adicionar documentos'),
            ),
            FilledButton.icon(
              onPressed: extracting || busy ? null : onStart,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Iniciar extração'),
            ),
          ],
        ),
        for (final file in files)
          ListTile(
            title: Text('${file['fileName']}'),
            trailing: IconButton(
              tooltip: 'Remover',
              onPressed: extracting ? null : () => onRemoveFile(file),
              icon: const Icon(Icons.close),
            ),
          ),
        TextField(
          controller: resumeController,
          enabled: !extracting,
          onChanged: (_) => onResumeChanged(),
          decoration: const InputDecoration(
            labelText: 'Token de retomada',
            helperText:
                'Guarde este identificador para retomar após uma interrupção.',
          ),
        ),
        Wrap(
          spacing: 12,
          children: [
            OutlinedButton(
              onPressed: extracting || resumeController.text.trim().isEmpty
                  ? null
                  : onResume,
              child: const Text('Retomar / reabrir resultado'),
            ),
            IconButton(
              tooltip: 'Copiar token',
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: resumeController.text)),
              icon: const Icon(Icons.copy),
            ),
          ],
        ),
        if (extracting) const LinearProgressIndicator(),
        if (monitorError.isNotEmpty) Text(monitorError),
        if (snapshot != null) ...[
          Text(
            'Estado: ${snapshot!['status']} · ${snapshot!['completedCalls'] ?? 0} chamadas preservadas',
          ),
          for (final event in records(
            object(snapshot!['activity'])['events'],
          ).reversed.take(12))
            Text('${event['stage']}: ${event['message']}'),
        ],
        if (extracted != null) ...[
          const Text('Resultado pronto para revisão'),
          Wrap(
            spacing: 12,
            children: [
              FilledButton(
                onPressed: onReviewResult,
                child: const Text('Revisar resultado'),
              ),
              OutlinedButton(
                onPressed: onDownloadResult,
                child: const Text('Baixar resultado'),
              ),
            ],
          ),
          SelectableText(
            prettyJson(extracted)
                .substring(0, prettyJson(extracted).length.clamp(0, 5000)),
          ),
        ],
      ]),
  ]);
}
