import 'package:flutter/material.dart';

class AdminLoginForm extends StatelessWidget {
  const AdminLoginForm({
    super.key,
    required this.serverAuthConfigured,
    required this.sessionConfigured,
    required this.busy,
    required this.showRetry,
    required this.message,
    required this.emailController,
    required this.passwordController,
    required this.onLogin,
    required this.onRetry,
  });
  final bool serverAuthConfigured;
  final bool sessionConfigured;
  final bool busy;
  final bool showRetry;
  final String message;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onLogin;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 420,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.lock_outline, size: 38),
                const SizedBox(height: 16),
                const Text(
                  'Admin My UFAPE',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Entre com uma conta autorizada para administrar os dados acadêmicos.',
                ),
                const SizedBox(height: 24),
                if (serverAuthConfigured != true)
                  const Text(
                    'Configure o Supabase e os administradores no servidor antes de entrar.',
                  ),
                if (!sessionConfigured)
                  const Text(
                    'Configure SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY no build Flutter.',
                  ),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(labelText: 'E-mail'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) {
                    if (!busy) onLogin();
                  },
                  decoration: const InputDecoration(labelText: 'Senha'),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed:
                      busy || !sessionConfigured || serverAuthConfigured != true
                      ? null
                      : onLogin,
                  child: Text(busy ? 'Verificando…' : 'Entrar'),
                ),
                if (message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: SelectableText(message),
                  ),
                if (showRetry)
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('Tentar novamente'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
