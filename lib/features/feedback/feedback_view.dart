import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'feedback_view_model.dart';
import 'widgets/feedback_form.dart';

class FeedbackView extends StatefulWidget {
  final FeedbackViewModel viewModel;
  final String view;
  const FeedbackView({super.key, required this.viewModel, required this.view});
  @override
  State<FeedbackView> createState() => _FeedbackViewState();
}

class _FeedbackViewState extends State<FeedbackView> {
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
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await widget.viewModel.submit(
        submissionId: submissionId,
        category: category,
        message: message.text.trim(),
        name: name.text.trim(),
        email: email.text.trim(),
        metadata: {
          'view': widget.view,
          'device': defaultTargetPlatform.name,
          'browser': kIsWeb ? 'Flutter Web' : 'Flutter Native',
          'viewport': '${size.width.round()}x${size.height.round()}',
          'theme': Theme.of(context).brightness.name,
          'version': const String.fromEnvironment(
            'APP_VERSION',
            defaultValue: 'flutter-1.0.0',
          ),
        },
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.viewModel.isLocal
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
      child: FeedbackForm(
        formKey: form,
        category: category,
        sending: sending,
        message: message,
        name: name,
        email: email,
        error: error,
        onCategoryChanged: (value) => setState(() => category = value),
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
