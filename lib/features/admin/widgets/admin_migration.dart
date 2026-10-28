import 'package:flutter/material.dart';

import '../../../data/parsers/admin_data.dart';
import '../../../services/files.dart';
import '../admin_view_model.dart';

class AdminMigration extends StatefulWidget {
  const AdminMigration({super.key, required this.viewModel});
  final AdminViewModel viewModel;
  @override
  State<AdminMigration> createState() => _AdminMigrationState();
}

class _AdminMigrationState extends State<AdminMigration> {
  AdminViewModel get _model => widget.viewModel;
  Json? get _inventory => _model.migrationInventory;
  Json? get _preview => _model.migrationPreview;
  Json? get _run => _model.migrationRun;
  List<Json> get _runs => _model.migrationRuns;
  Set<String> get _selected => _model.migrationSelected;
  Set<String> get _overwrite => _model.migrationOverwrite;
  bool get _busy => _model.isBusy;
  String _exportError = '';
  String get _message =>
      _exportError.isEmpty ? _model.migrationMessage : _exportError;
  int get _done => _model.migrationDone;
  int get _total => _model.migrationTotal;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _inventory == null) _model.analyzeMigration();
    });
  }

  Future<void> _execute() async {
    final preview = _preview;
    if (preview?['ready'] != true) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Executar migração?'),
        content: const Text(
          'Os conjuntos selecionados serão gravados no Supabase conforme a prévia. Os itens marcados para substituição terão seus dados atualizados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Migrar selecionados'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    await _model.executeMigration(preview!);
  }

  Future<void> _report(String id) async {
    setState(() => _exportError = '');
    final report = await _model.loadMigrationReport(id);
    if (!mounted || report == null) return;
    try {
      await saveJson('my-ufape-migration-$id.json', report);
    } catch (error) {
      if (mounted) setState(() => _exportError = '$error');
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        'Migração de dados',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 14),
      const Text(
        'Analise os arquivos do servidor, valide o destino e revise cada diferença antes de importar para o Supabase.',
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          OutlinedButton.icon(
            onPressed: _busy ? null : _model.analyzeMigration,
            icon: const Icon(Icons.refresh),
            label: const Text('Analisar arquivos'),
          ),
          OutlinedButton(
            onPressed: _busy ? null : _model.loadMigrationHistory,
            child: const Text('Carregar histórico'),
          ),
          FilledButton.tonal(
            onPressed:
                _busy ||
                    _selected.isEmpty ||
                    _inventory?['destinationConfigured'] != true
                ? null
                : _model.validateMigration,
            child: const Text('Validar seleção'),
          ),
          FilledButton(
            onPressed: _busy || _preview?['ready'] != true ? null : _execute,
            child: const Text('Migrar selecionados'),
          ),
        ],
      ),
      if (_busy) const LinearProgressIndicator(),
      if (_message.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: SelectableText(_message),
        ),
      if (_inventory != null) ...[
        const SizedBox(height: 18),
        SelectableText('Origem: ${_inventory!['sourceDirectory']}'),
        Text(
          'Destino configurado: ${_inventory!['destinationConfigured'] == true ? 'Sim' : 'Não'}',
        ),
        for (final item in records(_inventory!['items']))
          Card(
            child: Column(
              children: [
                CheckboxListTile(
                  value: _selected.contains(item['key']),
                  onChanged: _busy
                      ? null
                      : (value) => _model.selectMigrationItem(
                          '${item['key']}',
                          value == true,
                        ),
                  title: Text(
                    '${item['courseName']} · ${item['kind']} ${item['semester'] ?? ''}',
                  ),
                  subtitle: Text(
                    '${item['sourceFile']} · ${item['records']} registros',
                  ),
                ),
                if (_selected.contains(item['key']))
                  CheckboxListTile(
                    value: _overwrite.contains(item['key']),
                    onChanged: _busy
                        ? null
                        : (value) => _model.selectMigrationItem(
                            '${item['key']}',
                            value == true,
                            overwrite: true,
                          ),
                    title: const Text(
                      'Autorizar substituição se o destino for diferente',
                    ),
                  ),
              ],
            ),
          ),
        ExpansionTile(
          title: const Text('Arquivos ausentes ou ignorados'),
          children: [
            SelectableText(
              prettyJson({
                'missing': _inventory!['missing'],
                'ignoredFiles': _inventory!['ignoredFiles'],
              }),
            ),
          ],
        ),
      ],
      if (_preview != null) ...[
        const SizedBox(height: 18),
        Text(
          'Prévia: ${_preview!['ready'] == true ? 'Pronta' : 'Resolva os problemas'}',
        ),
        for (final item in records(_preview!['items']))
          ExpansionTile(
            title: Text(
              '${item['courseName']} · ${item['kind']} · ${item['status']}',
            ),
            subtitle: Text(
              '${item['records']} → ${item['destinationRecords']} registros no destino',
            ),
            children: [
              SelectableText(
                prettyJson({
                  'problems': item['problems'],
                  'warnings': item['warnings'],
                  'changes': item['changes'],
                }),
              ),
            ],
          ),
        if ((_preview!['errors'] as List? ?? []).isNotEmpty)
          SelectableText(prettyJson(_preview!['errors'])),
      ],
      if (_total > 0)
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Text('$_done de $_total cursos processados'),
              LinearProgressIndicator(value: _done / _total),
            ],
          ),
        ),
      if (_run != null)
        ListTile(
          title: Text('Última execução: ${_run!['status']}'),
          subtitle: Text('${_run!['id']}'),
          trailing: IconButton(
            tooltip: 'Baixar relatório',
            onPressed: _busy ? null : () => _report('${_run!['id']}'),
            icon: const Icon(Icons.download),
          ),
        ),
      for (final run in _runs)
        ListTile(
          title: Text('${run['status']} · ${run['created_at']}'),
          subtitle: Text('${run['id']}'),
          trailing: IconButton(
            tooltip: 'Baixar relatório',
            onPressed: _busy ? null : () => _report('${run['id']}'),
            icon: const Icon(Icons.download),
          ),
        ),
    ],
  );
}
