import 'package:flutter/material.dart';

import '../../../data/parsers/admin_data.dart';
import '../admin_view_model.dart';

const _feedbackStatuses = {
  'new': 'Novo',
  'reviewing': 'Em análise',
  'planned': 'Planejado',
  'resolved': 'Resolvido',
  'archived': 'Arquivado',
};
const _feedbackCategories = {
  'suggestion': 'Sugestão',
  'problem': 'Problema',
  'academic_data': 'Correção de dados acadêmicos',
  'other': 'Outro',
};

class AdminFeedback extends StatefulWidget {
  const AdminFeedback({
    super.key,
    required this.viewModel,
    required this.courses,
    required this.onStateChanged,
  });
  final AdminViewModel viewModel;
  final List<Json> courses;
  final void Function(bool dirty, bool saving) onStateChanged;
  @override
  State<AdminFeedback> createState() => _AdminFeedbackState();
}

class _AdminFeedbackState extends State<AdminFeedback> {
  List<Json> get _items => widget.viewModel.feedbackItems;
  Json? _selected;
  int get _total => widget.viewModel.feedbackTotal;
  int _offset = 0;
  String _statusFilter = '', _category = '', _course = '', _status = 'new';
  String get _error => widget.viewModel.feedbackMessage;
  final _notes = TextEditingController();
  bool get _busy => widget.viewModel.feedbackBusy;
  bool get _dirty =>
      _selected != null &&
      (_status != _selected!['status'] ||
          _notes.text != (_selected!['internal_notes'] ?? ''));
  void _notify() => widget.onStateChanged(_dirty, _busy);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<bool> _discard() async =>
      !_dirty ||
      (await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Notas não salvas'),
              content: const Text('Descartar as alterações deste feedback?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Descartar'),
                ),
              ],
            ),
          ) ??
          false);
  Future<void> _change(VoidCallback action) async {
    if (_busy || !await _discard() || !mounted) return;
    setState(action);
    await _load();
  }

  Future<void> _load() async {
    final operation = widget.viewModel.loadFeedback(
      category: _category,
      status: _statusFilter,
      course: _course,
      offset: _offset,
    );
    _notify();
    final loaded = await operation;
    if (!mounted) return;
    if (loaded) {
      _selected = _items
          .where((row) => row['id'] == _selected?['id'])
          .firstOrNull;
      _status = '${_selected?['status'] ?? 'new'}';
      _notes.text = '${_selected?['internal_notes'] ?? ''}';
    }
    setState(() {});
    _notify();
  }

  Future<void> _save() async {
    if (_selected == null || _busy) return;
    final operation = widget.viewModel.saveFeedback(
      '${_selected!['id']}',
      status: _status,
      notes: _notes.text,
    );
    _notify();
    final saved = await operation;
    if (!mounted) return;
    if (saved != null) {
      _selected = saved;
      _status = '${saved['status']}';
      _notes.text = '${saved['internal_notes'] ?? ''}';
    }
    setState(() {});
    _notify();
  }

  Widget _filter(
    String label,
    String value,
    Map<String, String> options,
    void Function(String) change,
  ) => SizedBox(
    width: 210,
    child: DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: '', child: Text('Todos')),
        for (final entry in options.entries)
          DropdownMenuItem(
            value: entry.key,
            child: Text(entry.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: _busy
          ? null
          : (value) => _change(() {
              _selected = null;
              change(value!);
              _offset = 0;
            }),
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty,
    onPopInvokedWithResult: (didPop, _) async {
      if (!didPop && await _discard() && context.mounted) {
        Navigator.pop(context);
      }
    },
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Caixa de entrada de feedbacks',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 14),
        const Text(
          'Mensagens privadas dos visitantes. As notas são internas; salvar não envia uma resposta por e-mail.',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _filter(
              'Situação',
              _statusFilter,
              _feedbackStatuses,
              (value) => _statusFilter = value,
            ),
            _filter(
              'Tipo',
              _category,
              _feedbackCategories,
              (value) => _category = value,
            ),
            _filter('Curso', _course, {
              for (final course in widget.courses)
                '${course['id']}': '${course['shortName']}',
            }, (value) => _course = value),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _change(() {}),
              icon: const Icon(Icons.refresh),
              label: const Text('Atualizar'),
            ),
          ],
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
        Text('$_total feedbacks encontrados'),
        for (final item in _items)
          Card(
            child: ListTile(
              selected: _selected?['id'] == item['id'],
              title: Text(
                '${_feedbackCategories[item['category']] ?? item['category']} · ${_feedbackStatuses[item['status']] ?? item['status']}',
              ),
              subtitle: Text(
                '${item['message']}\n${item['created_at']} · ${item['name'] ?? 'Sem nome'}',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: _busy
                  ? null
                  : () async {
                      if (await _discard() && mounted) {
                        setState(() {
                          _selected = item;
                          _status = '${item['status']}';
                          _notes.text = '${item['internal_notes'] ?? ''}';
                        });
                        _notify();
                      }
                    },
            ),
          ),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton(
              onPressed: _busy || _offset == 0
                  ? null
                  : () => _change(
                      () => _offset = (_offset - 25).clamp(0, _total),
                    ),
              child: const Text('Anterior'),
            ),
            Text(
              '${_total == 0 ? 0 : _offset + 1}–${(_offset + 25).clamp(0, _total)} de $_total',
            ),
            TextButton(
              onPressed: _busy || _offset + 25 >= _total
                  ? null
                  : () => _change(() => _offset += 25),
              child: const Text('Próxima'),
            ),
          ],
        ),
        if (_selected != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Detalhes',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 14),
                  SelectableText('${_selected!['message']}'),
                  const SizedBox(height: 14),
                  SelectableText(
                    'Nome: ${_selected!['name'] ?? 'Não informado'}\nE-mail: ${_selected!['email'] ?? 'Não informado'}\nRecebido: ${_selected!['created_at']}',
                  ),
                  ExpansionTile(
                    title: const Text('Contexto técnico'),
                    children: [
                      SelectableText(prettyJson(_selected!['metadata'])),
                    ],
                  ),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    key: ValueKey('status-${_selected!['id']}'),
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Situação'),
                    items: [
                      for (final entry in _feedbackStatuses.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) {
                            setState(() => _status = value!);
                            _notify();
                          },
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _notes,
                    enabled: !_busy,
                    minLines: 4,
                    maxLines: 8,
                    maxLength: 5000,
                    onChanged: (_) {
                      setState(() {});
                      _notify();
                    },
                    decoration: const InputDecoration(
                      labelText: 'Notas internas',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy || !_dirty ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Salvar feedback'),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
