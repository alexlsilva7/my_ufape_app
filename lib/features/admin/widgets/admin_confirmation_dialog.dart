import 'package:flutter/material.dart';

class AdminConfirmationDialog extends StatelessWidget {
  const AdminConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
  });
  final String title, message;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Confirmar'),
      ),
    ],
  );
}
