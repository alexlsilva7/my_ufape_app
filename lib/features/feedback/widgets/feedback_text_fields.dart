import 'package:flutter/material.dart';

class FeedbackTextFields extends StatelessWidget {
  const FeedbackTextFields({
    super.key,
    required this.message,
    required this.name,
    required this.email,
    required this.error,
  });

  final TextEditingController message;
  final TextEditingController name;
  final TextEditingController email;
  final String? error;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 16),
      TextFormField(
        controller: message,
        maxLines: 5,
        maxLength: 3000,
        decoration: const InputDecoration(labelText: 'Mensagem'),
        validator: (value) => value == null || value.trim().length < 10
            ? 'Escreva pelo menos 10 caracteres.'
            : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: name,
        maxLength: 100,
        decoration: const InputDecoration(labelText: 'Nome (opcional)'),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: email,
        maxLength: 254,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'E-mail (opcional)'),
        validator: (value) =>
            value != null &&
                value.trim().isNotEmpty &&
                !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
            ? 'Informe um e-mail válido.'
            : null,
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
    ],
  );
}
