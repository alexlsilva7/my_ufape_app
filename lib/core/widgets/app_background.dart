import 'package:flutter/material.dart';

/// The dotted canvas used by the home page and the rest of the application.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(painter: _DotGridPainter(dark), child: child);
  }
}

class _DotGridPainter extends CustomPainter {
  final bool dark;

  const _DotGridPainter(this.dark);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(
      dark ? const Color(0xff020617) : const Color(0xfff8fafc),
      BlendMode.src,
    );
    final paint = Paint()
      ..color = dark ? const Color(0xff1e293b) : const Color(0xffe5e7eb);
    for (double y = 8; y < size.height; y += 16) {
      for (double x = 8; x < size.width; x += 16) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter oldDelegate) => oldDelegate.dark != dark;
}
