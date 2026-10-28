import 'package:flutter/material.dart';

import 'dart:math' as math;

import 'package:flutter/gestures.dart';

import '../../../../core/models.dart';
import '../../widgets/academic_motion.dart';
import 'node_layer.dart';
import 'period_navigation.dart';
import 'prerequisite_layer.dart';

class MatrixGraph extends StatelessWidget {
  const MatrixGraph({
    super.key,
    required this.subjects,
    required this.periods,
    required this.subjectHeight,
    required this.transform,
    required this.onZoom,
    required this.onTransform,
    required this.onStopMotion,
    required this.onPointerSignal,
    required this.highlight,
    required this.onHoverExit,
    required this.headingBuilder,
    required this.cardBuilder,
    required this.onAddElective,
    required this.filtering,
    required this.onGeometry,
  });
  final List<Subject> subjects;
  final Map<int, List<Subject>> periods;
  final double Function(Subject) subjectHeight;
  final TransformationController transform;
  final ValueChanged<double> onZoom;
  final ValueChanged<Matrix4> onTransform;
  final VoidCallback onStopMotion;
  final ValueChanged<PointerSignalEvent> onPointerSignal;
  final ValueNotifier<Subject?> highlight;
  final ValueChanged<Subject> onHoverExit;
  final Widget Function(int, List<Subject>) headingBuilder;
  final Widget Function(Subject) cardBuilder;
  final VoidCallback onAddElective;
  final bool filtering;
  final void Function(double, double, double, bool) onGeometry;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const columnGap = 12.0, rowGap = 12.0;
      final cardWidth = constraints.maxWidth < 1000
          ? 220.0 *
                (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1, 1.5)
          : ((constraints.maxWidth - 16 - (periods.length - 1) * columnGap) /
                    periods.length)
                .clamp(112.0, 240.0);
      final header =
          78.0 +
          math.max(0, MediaQuery.textScalerOf(context).scale(12) - 12) * 3;
      final width = periods.length * (cardWidth + columnGap) - columnGap + 16;
      final nodes = <String, Rect>{};
      var column = 0;
      var height = 0.0;
      for (final list in periods.values) {
        var top = header;
        for (final subject in list) {
          final rect = Rect.fromLTWH(
            8 + column * (cardWidth + columnGap),
            top,
            cardWidth,
            subjectHeight(subject),
          );
          nodes[subject.id] = rect;
          if (subject.code != null) nodes[subject.code!] = rect;
          top += rect.height + rowGap;
        }
        height = math.max(height, top);
        column++;
      }
      height = math.max(
        height,
        periods.values.last.fold<double>(
              header,
              (top, subject) => top + subjectHeight(subject) + rowGap,
            ) +
            48,
      );
      height = math.max(height, 280);
      onGeometry(
        width,
        height,
        constraints.maxWidth,
        periods.length == 1 && filtering,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (constraints.maxWidth < 1000) ...[
            MatrixPeriodNavigation(
              periods: periods.keys.toList(),
              stride: cardWidth + columnGap,
              sceneWidth: width,
              viewportWidth: constraints.maxWidth,
              transform: transform,
              onZoom: onZoom,
              onTransform: onTransform,
            ),
            const SizedBox(height: 12),
          ],
          ClipRect(
            child: AcademicResize(
              child: SizedBox(
                height: height,
                child: Listener(
                  onPointerDown: (_) => onStopMotion(),
                  onPointerPanZoomStart: (_) => onStopMotion(),
                  onPointerSignal: onPointerSignal,
                  child: InteractiveViewer(
                    transformationController: transform,
                    scaleFactor: double.infinity,
                    trackpadScrollCausesScale: true,
                    constrained: false,
                    minScale: .35,
                    maxScale: 1.6,
                    boundaryMargin: const EdgeInsets.all(80),
                    alignment: Alignment.topLeft,
                    onInteractionStart: (_) => onStopMotion(),
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: MatrixPrerequisiteLayer(
                              subjects: subjects,
                              nodes: nodes,
                              highlight: highlight,
                            ),
                          ),
                          MatrixNodeLayer(
                            duration: academicMotionDuration(context, 240),
                            nodes: [
                              for (var c = 0; c < periods.length; c++)
                                MatrixNode(
                                  id: 'period-${periods.keys.elementAt(c)}',
                                  bounds: Rect.fromLTWH(
                                    8 + c * (cardWidth + columnGap),
                                    8,
                                    cardWidth,
                                    header - 16,
                                  ),
                                  child: headingBuilder(
                                    periods.keys.elementAt(c),
                                    periods.values.elementAt(c),
                                  ),
                                ),
                              for (final subject in subjects)
                                MatrixNode(
                                  id: subject.id,
                                  bounds: nodes[subject.id]!,
                                  child: MouseRegion(
                                    onEnter: (_) => highlight.value = subject,
                                    onExit: (_) {
                                      if (highlight.value?.id == subject.id) {
                                        onHoverExit(subject);
                                      }
                                    },
                                    child: cardBuilder(subject),
                                  ),
                                ),
                              if (!filtering)
                                MatrixNode(
                                  id: 'add-elective',
                                  bounds: Rect.fromLTWH(
                                    8 +
                                        (periods.length - 1) *
                                            (cardWidth + columnGap),
                                    periods.values.last.fold<double>(
                                      header,
                                      (top, subject) =>
                                          top + subjectHeight(subject) + rowGap,
                                    ),
                                    cardWidth,
                                    48,
                                  ),
                                  child: OutlinedButton.icon(
                                    onPressed: () => onAddElective(),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Adicionar optativa'),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (constraints.maxWidth >= 1000)
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Diminuir zoom',
                    onPressed: () => onZoom(.85),
                    icon: const Icon(Icons.zoom_out, size: 17),
                  ),
                  IconButton(
                    tooltip: 'Aumentar zoom',
                    onPressed: () => onZoom(1.15),
                    icon: const Icon(Icons.zoom_in, size: 17),
                  ),
                  IconButton(
                    tooltip: 'Restaurar posição',
                    onPressed: () => onTransform(Matrix4.identity()),
                    icon: const Icon(
                      Icons.center_focus_strong_outlined,
                      size: 17,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}
