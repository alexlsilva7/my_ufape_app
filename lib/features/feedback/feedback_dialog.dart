import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_state.dart';

class FeedbackDialog extends StatefulWidget {
  final AppState state;
  final String view;
  const FeedbackDialog({super.key, required this.state, required this.view});
  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final form = GlobalKey<FormState>();
  final message = TextEditingController(),
      name = TextEditingController(),
      email = TextEditingController();
  final submissionId = const Uuid().v4();
  String category = 'suggestion';
  bool sending = false;
  String? error;
  @override
  void dispose() {
    message.dispose();
    name.dispose();
    email.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (!form.currentState!.validate()) return;
    final size = MediaQuery.sizeOf(context);
    final state = widget.state;
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await state.repositories.feedback.submit({
        'submissionId': submissionId,
        'category': category,
        'message': message.text.trim(),
        'name': name.text.trim(),
        'email': email.text.trim(),
        'metadata': {
          'view': widget.view,
          'device': defaultTargetPlatform.name,
          'browser': kIsWeb ? 'Flutter Web' : 'Flutter Native',
          'viewport': '${size.width.round()}x${size.height.round()}',
          'theme': Theme.of(context).brightness.name,
          'version': const String.fromEnvironment(
            'APP_VERSION',
            defaultValue: 'flutter-1.0.0',
          ),
          'course': state.selectedCourse?.id ?? '',
          'semester': state.selectedSemester,
          'profile': state.selectedProfile,
        },
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              state.repositories.isLocal
                  ? 'Feedback salvo neste dispositivo.'
                  : 'Feedback enviado. Obrigado pela contribuição!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Enviar feedback'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Compartilhe sugestões, problemas ou correções nos dados acadêmicos.',
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(
                    value: 'suggestion',
                    child: Text('Sugestão'),
                  ),
                  DropdownMenuItem(value: 'problem', child: Text('Problema')),
                  DropdownMenuItem(
                    value: 'academic_data',
                    child: Text('Correção de dados acadêmicos'),
                  ),
                  DropdownMenuItem(value: 'other', child: Text('Outro')),
                ],
                onChanged: sending
                    ? null
                    : (value) => setState(() => category = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: message,
                maxLines: 5,
                maxLength: 3000,
                decoration: const InputDecoration(labelText: 'Mensagem'),
                validator: (v) => v == null || v.trim().length < 10
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
                decoration: const InputDecoration(
                  labelText: 'E-mail (opcional)',
                ),
                validator: (v) =>
                    v != null &&
                        v.trim().isNotEmpty &&
                        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch(v.trim())
                    ? 'Informe um e-mail válido.'
                    : null,
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: sending ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: sending ? null : send,
        child: Text(sending ? 'Enviando…' : 'Enviar'),
      ),
    ],
  );
}
