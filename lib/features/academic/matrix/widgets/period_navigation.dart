import 'dart:math' as math;

import 'package:flutter/material.dart';

class MatrixPeriodNavigation extends StatelessWidget {
  const MatrixPeriodNavigation({
    super.key,
    required this.periods,
    required this.stride,
    required this.sceneWidth,
    required this.viewportWidth,
    required this.transform,
    required this.onZoom,
    required this.onTransform,
  });

  final List<int> periods;
  final double stride, sceneWidth, viewportWidth;
  final TransformationController transform;
  final ValueChanged<double> onZoom;
  final ValueChanged<Matrix4> onTransform;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 8,
    children: [
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          const Text(
            'Deslize para ver os períodos',
            style: TextStyle(fontSize: 12),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Diminuir zoom',
                onPressed: () => onZoom(.85),
                icon: const Icon(Icons.zoom_out, size: 20),
              ),
              IconButton(
                tooltip: 'Aumentar zoom',
                onPressed: () => onZoom(1.15),
                icon: const Icon(Icons.zoom_in, size: 20),
              ),
              IconButton(
                tooltip: 'Restaurar posição',
                onPressed: () => onTransform(Matrix4.identity()),
                icon: const Icon(Icons.center_focus_strong_outlined, size: 20),
              ),
            ],
          ),
        ],
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ValueListenableBuilder<Matrix4>(
          valueListenable: transform,
          builder: (context, matrix, _) {
            final scale = matrix.getMaxScaleOnAxis();
            final offset = -matrix.entry(0, 3);
            final maxOffset = math.max(0.0, sceneWidth * scale - viewportWidth);
            final current = maxOffset > 0 && offset >= maxOffset - 1
                ? periods.length - 1
                : (offset / scale / stride).round().clamp(
                    0,
                    periods.length - 1,
                  );
            return Row(
              spacing: 8,
              children: [
                for (var index = 0; index < periods.length; index++)
                  ChoiceChip(
                    key: ValueKey('matrix-period-jump-${periods[index]}'),
                    label: Text(
                      periods[index] == 0
                          ? 'Optativas'
                          : '${periods[index]}º período',
                    ),
                    selected: current == index,
                    showCheckmark: false,
                    onSelected: (_) {
                      final target = transform.value.clone();
                      final zoom = target.getMaxScaleOnAxis();
                      final maxOffset = math.max(
                        0.0,
                        sceneWidth * zoom - viewportWidth,
                      );
                      target.setEntry(
                        0,
                        3,
                        -(index * stride * zoom).clamp(0.0, maxOffset),
                      );
                      onTransform(target);
                    },
                  ),
              ],
            );
          },
        ),
      ),
    ],
  );
}
