import 'package:flutter/material.dart';

import '../../widgets/academic_common.dart';
import '../../widgets/academic_motion.dart';
import '../../widgets/academic_palette.dart';

class MatrixLegend extends StatelessWidget {
  const MatrixLegend({super.key, required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 20,
    runSpacing: 10,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      for (final entry in statusNames.entries)
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            Icon(
              switch (entry.key) {
                'concluido' => Icons.check_circle_outline,
                'cursando' => Icons.timelapse,
                _ => Icons.circle_outlined,
              },
              size: 16,
              color: AcademicPalette.of(context).matrixStatusColor(entry.key),
            ),
            Flexible(
              child: Text(entry.value, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      const Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Icon(Icons.lock_outline, size: 16),
          Flexible(
            child: Text(
              'Pré-requisito pendente',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
      AcademicTransition(
        identity: count,
        duration: academicMotionDuration(context, 160),
        child: Text(
          '$count disciplinas',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
}
