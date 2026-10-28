import 'package:flutter/material.dart';

class HomeHero extends StatelessWidget {
  const HomeHero({
    super.key,
    required this.dark,
    required this.muted,
    required this.width,
    required this.compact,
  });
  final bool dark;
  final Color muted;
  final double width;
  final bool compact;
  @override
  Widget build(BuildContext context) => Column(
    spacing: compact ? 12 : 16,
    children: [
      Image.asset(
        dark
            ? 'assets/images/my_ufape_logo_azul.png'
            : 'assets/images/my_ufape_logo.png',
        width: compact ? 64 : 96,
        height: compact ? 64 : 96,
        fit: BoxFit.contain,
        semanticLabel: 'My UFAPE Logo',
      ),
      Text(
        'My UFAPE',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: !compact && width >= 768 ? 48 : 28,
          height: 1,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
          color: dark ? const Color(0xfff8fafc) : const Color(0xff0f172a),
        ),
      ),
      Text(
        'Seu assistente acadêmico para o planejamento e acompanhamento curricular',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: compact ? 14 : 18,
          height: 1.55,
          color: muted,
        ),
      ),
    ],
  );
}
