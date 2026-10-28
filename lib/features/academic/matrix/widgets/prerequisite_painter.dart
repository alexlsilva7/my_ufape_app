import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../../../core/models.dart';

class _Route {
  _Route(this.path, this.metric, this.end, this.incoming);
  final Path path;
  final PathMetric metric;
  final Offset end;
  final bool incoming;
}

class MatrixPrerequisitePainter extends CustomPainter {
  MatrixPrerequisitePainter({
    required this.subjects,
    required this.nodes,
    required this.highlight,
    required this.reveal,
    required this.color,
    required this.muted,
  }) : super(repaint: reveal) {
    if (highlight == null) return;
    final highlightedBounds = nodes[highlight];
    for (final subject in subjects) {
      final target = nodes[subject.id];
      if (target == null) continue;
      final incoming = highlight == subject.id;
      for (final prerequisite in subject.prereqs) {
        final source = nodes[prerequisite];
        if (source == null || (!incoming && highlightedBounds != source)) {
          continue;
        }
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
        _routes.add(_Route(path, path.computeMetrics().first, end, incoming));
      }
    }
  }
  final List<Subject> subjects;
  final Map<String, Rect> nodes;
  final String? highlight;
  final Animation<double> reveal;
  final Color color, muted;
  final _routes = <_Route>[];

  @override
  void paint(Canvas canvas, Size size) {
    final amount = reveal.value;
    if (amount <= 0) return;
    final incomingPaint = Paint()
      ..color = color.withValues(alpha: .85 * amount)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;
    final outgoingPaint = Paint()
      ..color = muted.withValues(alpha: .85 * amount)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;
    for (final route in _routes) {
      final paint = route.incoming ? incomingPaint : outgoingPaint;
      canvas.drawPath(
        amount >= 1
            ? route.path
            : route.metric.extractPath(0, route.metric.length * amount),
        paint,
      );
      if (amount < .95) continue;
      final end = route.end;
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
