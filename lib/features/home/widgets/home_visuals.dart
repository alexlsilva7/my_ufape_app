import 'package:flutter/material.dart';

import '../../academic/widgets/academic_motion.dart';

const homeIndigo = Color(0xff4f46e5);
const homeEmerald = Color(0xff059669);
const homeViolet = Color(0xff7c3aed);

Color homeSurface(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xff0f172a)
    : Colors.white;
Color homeBorder(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xff1e293b)
    : const Color(0xffe2e8f0);

class HomeTextLink extends StatelessWidget {
  const HomeTextLink(
    this.text, {
    super.key,
    required this.onTap,
    this.color = homeIndigo,
    this.size = 14,
    this.underline = false,
  });

  final String text;
  final VoidCallback onTap;
  final Color color;
  final double size;
  final bool underline;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          child: Text(
            text,
            style: TextStyle(
              fontSize: size,
              height: 1.5,
              color: color,
              decoration: underline ? TextDecoration.underline : null,
              decorationColor: color,
            ),
          ),
        ),
      ),
    ),
  );
}

class HomePanel extends StatelessWidget {
  const HomePanel({super.key, required this.child, required this.padding});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: homeSurface(context),
      border: Border.all(color: homeBorder(context)),
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0d0f172a),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
      ],
    ),
    padding: padding,
    child: child,
  );
}

class HomeButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color accent;
  final Color? border;
  final double radius;
  const HomeButton({
    super.key,
    required this.child,
    required this.onTap,
    required this.accent,
    this.border,
    this.radius = 16,
  });
  @override
  State<HomeButton> createState() => HomeButtonState();
}

class HomeButtonState extends State<HomeButton> {
  bool hover = false, _focused = false, _pressed = false;
  bool get _raised => hover || _focused;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale:
            academicMotionDuration(context, 120) == Duration.zero || !_pressed
            ? 1
            : .985,
        duration: academicMotionDuration(context, 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: academicMotionDuration(context, 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(
            0,
            _raised &&
                    !_pressed &&
                    academicMotionDuration(context, 180) != Duration.zero
                ? -3
                : 0,
            0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff0f172a)
                    .withValues(alpha: _raised ? .10 : .08),
                blurRadius: _raised ? 12 : 2,
                offset: Offset(0, _raised ? 5 : 1),
              ),
            ],
          ),
          child: Material(
            color: homeSurface(context),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.radius),
              side: BorderSide(
                color: _raised
                    ? widget.accent.withValues(alpha: .5)
                    : widget.border ?? homeBorder(context),
              ),
            ),
            child: InkWell(
              onTap: widget.onTap,
              onFocusChange: (value) => setState(() => _focused = value),
              onHighlightChanged: (value) => setState(() => _pressed = value),
              hoverColor: widget.accent.withValues(alpha: .035),
              splashColor: widget.accent.withValues(alpha: .1),
              child: widget.child,
            ),
          ),
        ),
      ),
    ),
  );
}

class HomeIconTile extends StatelessWidget {
  final HomeLineIcon kind;
  final Color color;
  final double size;
  const HomeIconTile({
    super.key,
    required this.kind,
    required this.color,
    this.size = 48,
  });
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = color == homeEmerald
        ? const Color(0xffecfdf5)
        : color == homeViolet
        ? const Color(0xfff5f3ff)
        : const Color(0xffeef2ff);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dark ? color.withValues(alpha: .14) : background,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: HomeStrokeIcon(
        kind,
        color: dark ? Color.lerp(color, Colors.white, .35)! : color,
      ),
    );
  }
}

enum HomeLineIcon { book, calendar, layers, arrow, chat, github, external }

class HomeStrokeIcon extends StatelessWidget {
  final HomeLineIcon kind;
  final Color color;
  final double size;
  const HomeStrokeIcon(
    this.kind, {
    super.key,
    required this.color,
    this.size = 24,
  });
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _StrokePainter(kind, color)),
  );
}

// Stroke geometry follows the site's Lucide icons.
class _StrokePainter extends CustomPainter {
  final HomeLineIcon kind;
  final Color color;
  const _StrokePainter(this.kind, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    switch (kind) {
      case HomeLineIcon.book:
        path.moveTo(12, 7);
        path.cubicTo(9, 3, 4, 3, 2, 4);
        path.lineTo(2, 20);
        path.cubicTo(5, 19, 9, 19, 12, 22);
        path.cubicTo(15, 19, 19, 19, 22, 20);
        path.lineTo(22, 4);
        path.cubicTo(19, 3, 15, 3, 12, 7);
        path.lineTo(12, 22);
      case HomeLineIcon.calendar:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 5, 18, 17),
            const Radius.circular(2),
          ),
          pen,
        );
        path.moveTo(16, 3);
        path.lineTo(16, 7);
        path.moveTo(8, 3);
        path.lineTo(8, 7);
        path.moveTo(3, 11);
        path.lineTo(21, 11);
        for (final y in [15.0, 18.0]) {
          for (final x in [8.0, 12.0, 16.0]) {
            canvas.drawCircle(Offset(x, y), .75, Paint()..color = color);
          }
        }
      case HomeLineIcon.layers:
        path.moveTo(12, 2);
        path.lineTo(22, 7);
        path.lineTo(12, 12);
        path.lineTo(2, 7);
        path.close();
        path.moveTo(2, 12);
        path.lineTo(12, 17);
        path.lineTo(22, 12);
        path.moveTo(2, 17);
        path.lineTo(12, 22);
        path.lineTo(22, 17);
      case HomeLineIcon.arrow:
        path.moveTo(5, 12);
        path.lineTo(19, 12);
        path.moveTo(12, 5);
        path.lineTo(19, 12);
        path.lineTo(12, 19);
      case HomeLineIcon.chat:
        path.moveTo(21, 15);
        path.quadraticBezierTo(21, 18, 18, 18);
        path.lineTo(7, 18);
        path.lineTo(3, 22);
        path.lineTo(3, 6);
        path.quadraticBezierTo(3, 3, 6, 3);
        path.lineTo(18, 3);
        path.quadraticBezierTo(21, 3, 21, 6);
        path.close();
      case HomeLineIcon.external:
        path.moveTo(15, 3);
        path.lineTo(21, 3);
        path.lineTo(21, 9);
        path.moveTo(10, 14);
        path.lineTo(21, 3);
        path.moveTo(21, 14);
        path.lineTo(21, 19);
        path.quadraticBezierTo(21, 21, 19, 21);
        path.lineTo(5, 21);
        path.quadraticBezierTo(3, 21, 3, 19);
        path.lineTo(3, 5);
        path.quadraticBezierTo(3, 3, 5, 3);
        path.lineTo(10, 3);
      case HomeLineIcon.github:
        path.moveTo(9, 19);
        path.cubicTo(4, 21, 4, 16, 2, 16);
        path.moveTo(9, 22);
        path.lineTo(9, 18);
        path.cubicTo(9, 17, 9.2, 16, 10, 16);
        path.cubicTo(4, 15.5, 3, 13, 3, 10);
        path.cubicTo(3, 8, 4, 7, 4, 7);
        path.cubicTo(3.5, 5, 4, 3, 4, 3);
        path.cubicTo(6, 3, 8, 4, 8, 4);
        path.cubicTo(11, 3, 13, 3, 16, 4);
        path.cubicTo(16, 4, 18, 3, 20, 3);
        path.cubicTo(20, 3, 20.5, 5, 20, 7);
        path.cubicTo(20, 7, 21, 8, 21, 10);
        path.cubicTo(21, 13, 20, 15.5, 14, 16);
        path.cubicTo(15, 17, 15, 18, 15, 19);
        path.lineTo(15, 22);
    }
    canvas.drawPath(path, pen);
  }

  @override
  bool shouldRepaint(_StrokePainter oldDelegate) =>
      kind != oldDelegate.kind || color != oldDelegate.color;
}
