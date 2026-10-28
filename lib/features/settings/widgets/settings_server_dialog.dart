import 'package:flutter/material.dart';

class SettingsServerDialog extends StatefulWidget {
  const SettingsServerDialog({super.key, required this.initialUrl});
  final String initialUrl;
  @override
  State<SettingsServerDialog> createState() => _SettingsServerDialogState();
}

class _SettingsServerDialogState extends State<SettingsServerDialog> {
  late final input = TextEditingController(text: widget.initialUrl);
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
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
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, input.text.trim()),
        child: const Text('Conectar'),
      ),
    ],
  );
}
