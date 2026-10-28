import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../data/parsers/admin_data.dart';

class JsonEditorDialog extends StatefulWidget {
  const JsonEditorDialog({super.key, required this.title, required this.value});
  final String title;
  final dynamic value;
  @override
  State<JsonEditorDialog> createState() => _JsonEditorDialogState();
}

class _JsonEditorDialogState extends State<JsonEditorDialog> {
  late final _controller = TextEditingController(
    text: prettyJson(widget.value),
  );
  String? _error;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 850,
      height: 530,
      child: Column(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              expands: true,
              minLines: null,
              maxLines: null,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(
                alignLabelWithHint: true,
                labelText: 'JSON',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          try {
            Navigator.pop(context, jsonDecode(_controller.text));
          } catch (error) {
            setState(() => _error = 'JSON inválido: $error');
          }
        },
        child: const Text('Aplicar ao rascunho'),
      ),
    ],
  );
}
