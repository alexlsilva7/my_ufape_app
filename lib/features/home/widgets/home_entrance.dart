import 'package:flutter/material.dart';

import '../../academic/widgets/academic_motion.dart';

/// A short, one-time entrance. Theme and data updates do not replay it.
class HomeEntrance extends StatefulWidget {
  const HomeEntrance({super.key, required this.child, this.order = 0});
  final Widget child;
  final int order;
  @override
  State<HomeEntrance> createState() => _HomeEntranceState();
}

class _HomeEntranceState extends State<HomeEntrance>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this);
  late Animation<double> _appearance;
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final delay = widget.order.clamp(0, 3) * 70;
    final duration = academicMotionDuration(context, 360 + delay);
    _controller.duration = duration;
    _appearance = _controller.drive(
      CurveTween(
        curve: Interval(delay / (360 + delay), 1, curve: Curves.easeOutCubic),
      ),
    );
    if (duration == Duration.zero) {
      _started = true;
      _controller.value = 1;
    } else if (!_started) {
      _started = true;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _appearance,
    child: SlideTransition(
      position: Tween(
        begin: const Offset(0, .025),
        end: Offset.zero,
      ).animate(_appearance),
      child: RepaintBoundary(child: widget.child),
    ),
  );
}
