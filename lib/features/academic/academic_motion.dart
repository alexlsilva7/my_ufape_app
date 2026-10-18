import 'package:flutter/material.dart';

Duration academicMotionDuration(
  BuildContext context,
  int milliseconds, {
  bool disabled = false,
}) =>
    disabled ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

/// Keeps outgoing content visible briefly, without leaving its controls active.
class AcademicTransition extends StatelessWidget {
  const AcademicTransition({
    super.key,
    required this.identity,
    required this.duration,
    required this.child,
    this.slide = false,
  });

  final Object identity;
  final Duration duration;
  final Widget child;
  final bool slide;

  @override
  Widget build(BuildContext context) {
    if (duration == Duration.zero) return child;
    return AnimatedSwitcher(
      duration: duration,
      reverseDuration: Duration(milliseconds: duration.inMilliseconds * 2 ~/ 3),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topLeft,
        children: [
          for (final outgoing in previous)
            ExcludeSemantics(
              child: ExcludeFocus(child: IgnorePointer(child: outgoing)),
            ),
          ?current,
        ],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: slide
            ? SlideTransition(
                position: Tween(
                  begin: const Offset(0, .018),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              )
            : ScaleTransition(
                scale: Tween(begin: .94, end: 1.0).animate(animation),
                child: child,
              ),
      ),
      child: KeyedSubtree(key: ValueKey(identity), child: child),
    );
  }
}

/// Switches form sections without leaving the departing inputs interactive.
class AcademicFormSection extends StatelessWidget {
  const AcademicFormSection({
    super.key,
    required this.identity,
    required this.child,
  });

  final Object identity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = academicMotionDuration(context, 220);
    if (duration == Duration.zero) return child;
    return AnimatedSwitcher(
      duration: duration,
      reverseDuration: const Duration(milliseconds: 150),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topLeft,
        children: [
          for (final outgoing in previous)
            ExcludeSemantics(
              child: ExcludeFocus(child: IgnorePointer(child: outgoing)),
            ),
          ?current,
        ],
      ),
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        alignment: Alignment.topLeft,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: KeyedSubtree(key: ValueKey(identity), child: child),
    );
  }
}

AnimationStyle academicDialogMotion(BuildContext context) => AnimationStyle(
  duration: academicMotionDuration(context, 240),
  reverseDuration: academicMotionDuration(context, 160),
  curve: Curves.easeOutCubic,
  reverseCurve: Curves.easeInCubic,
);
