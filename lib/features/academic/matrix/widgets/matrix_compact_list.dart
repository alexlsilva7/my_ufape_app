import 'package:flutter/material.dart';

import '../../../../core/models.dart';
import 'matrix_motion.dart';

class MatrixCompactList extends StatelessWidget {
  const MatrixCompactList({
    super.key,
    required this.periods,
    required this.headingBuilder,
    required this.cardBuilder,
    required this.subjectHeight,
  });
  final Map<int, List<Subject>> periods;
  final Widget Function(int, List<Subject>) headingBuilder;
  final Widget Function(Subject) cardBuilder;
  final double Function(Subject) subjectHeight;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final entry in periods.entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: headingBuilder(entry.key, entry.value),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final count = (constraints.maxWidth / 300).floor().clamp(
                    1,
                    5,
                  );
                  final width =
                      (constraints.maxWidth - (count - 1) * 12) / count;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final (index, subject) in entry.value.indexed)
                        SizedBox(
                          key: ValueKey('matrix-item-${subject.id}'),
                          width: width,
                          height: subjectHeight(subject),
                          child: MatrixCardEntrance(
                            order: index,
                            child: cardBuilder(subject),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
    ],
  );
}
