import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models.dart';

class MatrixPrerequisitePainter extends CustomPainter {
  const MatrixPrerequisitePainter({
    required this.subjects,
    required this.nodes,
    required this.highlight,
    required this.reveal,
    required this.color,
    required this.muted,
  });
  final List<Subject> subjects;
  final Map<String, Rect> nodes;
  final String? highlight;
  final double reveal;
  final Color color, muted;
  @override
  void paint(Canvas canvas, Size size) {
    if (reveal <= 0) return;
    for (final subject in subjects) {
      final target = nodes[subject.id];
      if (target == null) continue;
      for (final prerequisite in subject.prereqs) {
        final source = nodes[prerequisite];
        if (source == null) continue;
        if (highlight == null) continue;
        final active = highlight == subject.id || nodes[highlight] == source;
        if (!active) continue;
        final paint = Paint()
          ..color = (highlight == subject.id ? color : muted).withValues(
            alpha: .85 * reveal,
          )
          ..strokeWidth = 2.4
          ..style = PaintingStyle.stroke;
        final start = source.centerRight, end = target.centerLeft;
        final bend = math.max(18.0, (end.dx - start.dx).abs() * .45);
        final path = Path()
          ..moveTo(start.dx, start.dy)
          ..cubicTo(
            start.dx + bend,
            start.dy,
            end.dx - bend,
            end.dy,
            end.dx - 3,
            end.dy,
          );
        final metric = path.computeMetrics().first;
        canvas.drawPath(metric.extractPath(0, metric.length * reveal), paint);
        if (reveal < .95) continue;
        canvas.drawLine(
          Offset(end.dx - 9, end.dy - 4),
          Offset(end.dx - 3, end.dy),
          paint,
        );
        canvas.drawLine(
          Offset(end.dx - 9, end.dy + 4),
          Offset(end.dx - 3, end.dy),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant MatrixPrerequisitePainter oldDelegate) =>
      oldDelegate.subjects != subjects ||
      oldDelegate.highlight != highlight ||
      oldDelegate.reveal != reveal ||
      oldDelegate.color != color ||
      oldDelegate.muted != muted ||
      oldDelegate.nodes.length != nodes.length ||
      nodes.entries.any((entry) => oldDelegate.nodes[entry.key] != entry.value);
}
