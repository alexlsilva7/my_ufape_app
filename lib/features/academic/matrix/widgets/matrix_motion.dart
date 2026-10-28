import 'package:flutter/material.dart';

import '../../widgets/academic_motion.dart';

class MatrixCardEntrance extends StatelessWidget {
  const MatrixCardEntrance({
    super.key,
    required this.order,
    required this.child,
  });

  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (academicMotionDuration(context, 260) == Duration.zero) return child;
    final delay = order.clamp(0, 6) * 16;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + delay),
      curve: Interval(delay / (260 + delay), 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, 8 * (1 - value)),
        child: Opacity(opacity: value, child: child),
      ),
    );
  }
}

/// Paint-only feedback keeps the card's layout stable.
class MatrixCardFeedback extends StatefulWidget {
  const MatrixCardFeedback({super.key, required this.child});

  final Widget child;

  @override
  State<MatrixCardFeedback> createState() => _MatrixCardFeedbackState();
}

class _MatrixCardFeedbackState extends State<MatrixCardFeedback> {
  bool _hovered = false, _focused = false, _pressed = false;

  @override
  Widget build(BuildContext context) {
    final duration = academicMotionDuration(context, _pressed ? 90 : 180);
    final raised = _hovered || _focused;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Focus(
        canRequestFocus: false,
        onFocusChange: (value) => setState(() => _focused = value),
        child: Listener(
          onPointerDown: (_) => setState(() => _pressed = true),
          onPointerUp: (_) => setState(() => _pressed = false),
          onPointerCancel: (_) => setState(() => _pressed = false),
          child: AnimatedScale(
            key: const ValueKey('matrix-card-feedback'),
            duration: duration,
            curve: Curves.easeOutCubic,
            scale: duration == Duration.zero
                ? 1
                : _pressed
                ? .985
                : raised
                ? 1.012
                : 1,
            child: AnimatedSlide(
              duration: duration,
              curve: Curves.easeOutCubic,
              offset: duration != Duration.zero && raised && !_pressed
                  ? const Offset(0, -.012)
                  : Offset.zero,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
