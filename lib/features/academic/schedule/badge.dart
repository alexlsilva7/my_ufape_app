import 'package:flutter/material.dart';

import '../academic_motion.dart';
import '../academic_palette.dart';

class ScheduleBadge extends StatelessWidget {
  const ScheduleBadge(
    this.text, {
    super.key,
    this.background,
    this.foreground,
    this.disableMotion = false,
  });
  final String text;
  final Color? background, foreground;
  final bool disableMotion;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: academicMotionDuration(context, 180, disabled: disableMotion),
    curve: Curves.easeOutCubic,
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
    decoration: BoxDecoration(
      color: background ?? AcademicPalette.of(context).canvas,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: foreground ?? AcademicPalette.of(context).ink,
      ),
    ),
  );
}
