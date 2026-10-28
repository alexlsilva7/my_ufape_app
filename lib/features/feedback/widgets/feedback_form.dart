import 'package:flutter/material.dart';

import 'feedback_text_fields.dart';

class FeedbackForm extends StatelessWidget {
  const FeedbackForm({
    super.key,
    required this.formKey,
    required this.category,
    required this.sending,
    required this.message,
    required this.name,
    required this.email,
    required this.error,
    required this.onCategoryChanged,
  });
  final GlobalKey<FormState> formKey;
  final String category;
  final bool sending;
  final TextEditingController message;
  final TextEditingController name;
  final TextEditingController email;
  final String? error;
  final ValueChanged<String> onCategoryChanged;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Form(
      key: formKey,
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
              DropdownMenuItem(value: 'suggestion', child: Text('Sugestão')),
              DropdownMenuItem(value: 'problem', child: Text('Problema')),
              DropdownMenuItem(
                value: 'academic_data',
                child: Text('Correção de dados acadêmicos'),
              ),
              DropdownMenuItem(value: 'other', child: Text('Outro')),
            ],
            onChanged: sending
                ? null
                : (value) {
                    if (value != null) onCategoryChanged(value);
                  },
          ),
          FeedbackTextFields(
            message: message,
            name: name,
            email: email,
            error: error,
          ),
        ],
      ),
    ),
  );
}
