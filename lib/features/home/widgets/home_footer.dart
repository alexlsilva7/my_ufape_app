import 'package:flutter/material.dart';

import 'home_visuals.dart';

import 'package:url_launcher/url_launcher.dart';

class HomeFooter extends StatelessWidget {
  const HomeFooter({super.key, required this.muted, required this.onFeedback});
  final Color muted;
  final VoidCallback? onFeedback;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: homeBorder(context))),
    ),
    padding: const EdgeInsets.only(top: 24),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= 640 &&
            MediaQuery.textScalerOf(context).scale(14) <= 21;
        final message = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            const Text(
              'Ajude a melhorar o My UFAPE',
              style: TextStyle(fontWeight: FontWeight.w600, height: 1.5),
            ),
            Text(
              'Envie sugestões ou relate problemas. Não é necessário criar uma conta.',
              style: TextStyle(fontSize: 12, height: 1.625, color: muted),
            ),
          ],
        );
        final feedback = FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: homeIndigo,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: onFeedback,
          icon: const HomeStrokeIcon(
            HomeLineIcon.chat,
            color: Colors.white,
            size: 16,
          ),
          label: const Text('Enviar feedback'),
        );
        final author = Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Desenvolvido por ',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            HomeTextLink(
              'Alex Lopes',
              onTap: () => _open('https://github.com/alexlsilva7'),
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xffe2e8f0)
                  : const Color(0xff334155),
              size: 12,
              underline: true,
            ),
          ],
        );
        final repo = Semantics(
          link: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _open('https://github.com/alexlsilva7/my_ufape_app'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  HomeStrokeIcon(HomeLineIcon.github, color: muted, size: 16),
                  Flexible(
                    child: Text(
                      'Repositório no GitHub',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ),
                  HomeStrokeIcon(HomeLineIcon.external, color: muted, size: 12),
                ],
              ),
            ),
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (wide)
              Row(
                spacing: 24,
                children: [
                  Expanded(child: message),
                  feedback,
                ],
              )
            else ...[
              message,
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: feedback),
            ],
            const SizedBox(height: 20),
            if (wide)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [author, repo],
              )
            else ...[
              author,
              const SizedBox(height: 8),
              repo,
            ],
          ],
        );
      },
    ),
  );
  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
