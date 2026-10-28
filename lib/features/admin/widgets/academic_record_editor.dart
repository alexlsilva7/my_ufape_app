import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../data/parsers/admin_data.dart';
import 'json_editor_dialog.dart';

class AcademicRecordEditor extends StatefulWidget {
  const AcademicRecordEditor({
    super.key,
    required this.initial,
    required this.schedule,
  });
  final Json initial;
  final bool schedule;
  @override
  State<AcademicRecordEditor> createState() => _AcademicRecordEditorState();
}

class _AcademicRecordEditorState extends State<AcademicRecordEditor> {
  late final Json _row = object(cloneJson(widget.initial));
  String _error = '';
  final List<TextEditingController> _controllers = [];
  late final Map<String, TextEditingController> _fields = {
    for (final key in [
      'code',
      'name',
      'professor',
      'period',
      'profile',
      'type',
      'credits',
      'ementa',
    ])
      key: _controller('${_row[key] ?? ''}'),
  };
  late final _sessions = _controller(prettyJson(_row['sessions'] ?? []));
  late final _workload = _controller(prettyJson(_row['workload'] ?? {}));
  TextEditingController _controller(String value) {
    final controller = TextEditingController(text: value);
    _controllers.add(controller);
    return controller;
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    try {
      for (final entry in _fields.entries) {
        _row[entry.key] = entry.value.text.trim().isEmpty
            ? null
            : entry.value.text.trim();
      }
      _row['period'] =
          num.tryParse(_fields['period']!.text) ??
          (_fields['period']!.text.isEmpty ? null : _fields['period']!.text);
      _row['credits'] = num.tryParse(_fields['credits']!.text);
      if (widget.schedule) {
        final value = jsonDecode(_sessions.text);
        if (value is! List) {
          throw const FormatException('Encontros deve ser uma lista.');
        }
        _row['sessions'] = value;
      } else {
        _row['workload'] = jsonDecode(_workload.text);
      }
      final errors = validateAdminData(
        widget.schedule
            ? [_row]
            : {
                'subjects': [_row],
              },
        schedule: widget.schedule,
      );
      if (errors.isNotEmpty) throw FormatException(errors.join('\n'));
      Navigator.pop(context, _row);
    } catch (error) {
      setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.schedule ? 'Editar turma' : 'Editar disciplina'),
    content: SizedBox(
      width: 680,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in {
              'code': 'Código',
              'name': 'Nome',
              if (widget.schedule) 'professor': 'Professor',
              'period': 'Período',
              'profile': 'Perfil (identificador)',
              if (!widget.schedule) ...{
                'type': 'Tipo acadêmico',
                'credits': 'Créditos',
                'ementa': 'Ementa',
              },
            }.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TextField(
                  controller: _fields[entry.key],
                  maxLines: entry.key == 'ementa' ? 4 : 1,
                  decoration: InputDecoration(labelText: entry.value),
                ),
              ),
            TextField(
              controller: widget.schedule ? _sessions : _workload,
              minLines: 5,
              maxLines: 10,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                labelText: widget.schedule
                    ? 'Encontros: JSON [{"day":1,"time":"07:30 - 08:30"}]'
                    : 'Carga horária (JSON)',
              ),
            ),
            TextButton(
              onPressed: () async {
                final result = await showDialog<dynamic>(
                  context: context,
                  builder: (context) => JsonEditorDialog(
                    title: 'Campos completos e referências',
                    value: _row,
                  ),
                );
                if (result is Map && context.mounted) {
                  Navigator.pop(context, object(result));
                }
              },
              child: const Text(
                'Editar todos os campos em JSON (pré-requisitos, equivalências e evidências)',
              ),
            ),
            if (_error.isNotEmpty)
              Text(
                _error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _save, child: const Text('Aplicar ao rascunho')),
    ],
  );
}
