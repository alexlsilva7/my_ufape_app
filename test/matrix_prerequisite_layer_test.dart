import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ufape/core/models.dart';
import 'package:my_ufape/features/academic/matrix/widgets/prerequisite_layer.dart';
import 'package:my_ufape/features/academic/matrix/widgets/prerequisite_painter.dart';

final subjects = [
  Subject.fromJson({'id': 'a', 'code': 'CODE-A', 'name': 'A'}),
  Subject.fromJson({
    'id': 'b',
    'name': 'B',
    'prereqs': ['CODE-A'],
  }),
  Subject.fromJson({'id': 'unrelated', 'name': 'Unrelated'}),
];
const nodes = {
  'a': Rect.fromLTWH(0, 20, 50, 60),
  'CODE-A': Rect.fromLTWH(0, 20, 50, 60),
  'b': Rect.fromLTWH(150, 20, 50, 60),
};

void main() {
  testWidgets('prerequisite animation repaints without replacing its painter', (
    tester,
  ) async {
    final hover = ValueNotifier<Subject?>(null);
    addTearDown(hover.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 220,
          height: 100,
          child: MatrixPrerequisiteLayer(
            subjects: subjects,
            nodes: nodes,
            highlight: hover,
          ),
        ),
      ),
    );
    MatrixPrerequisitePainter painter() =>
        tester
                .widget<CustomPaint>(
                  find.byWidgetPredicate(
                    (widget) =>
                        widget is CustomPaint &&
                        widget.painter is MatrixPrerequisitePainter,
                  ),
                )
                .painter!
            as MatrixPrerequisitePainter;
    hover.value = subjects.first;
    await tester.pump();
    final active = painter();
    await tester.pump(const Duration(milliseconds: 70));
    expect(active.reveal.value, inExclusiveRange(0, 1));
    expect(painter(), same(active));
    await tester.pumpAndSettle();
    expect(active.reveal.value, 1);
    hover.value = null;
    await tester.pump(const Duration(milliseconds: 70));
    expect(painter(), same(active));
    await tester.pumpAndSettle();
    expect(active.reveal.value, 0);
    hover.value = subjects[1];
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    hover.value = subjects.first;
    await tester.pumpAndSettle();
    expect(painter().highlight, 'a');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion reveals prerequisite lines immediately', (
    tester,
  ) async {
    final hover = ValueNotifier<Subject?>(null);
    addTearDown(hover.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: MatrixPrerequisiteLayer(
          subjects: subjects,
          nodes: nodes,
          highlight: hover,
        ),
      ),
    );
    hover.value = subjects.first;
    await tester.pump();
    final paint =
        tester
                .widget<CustomPaint>(
                  find.byWidgetPredicate(
                    (widget) =>
                        widget is CustomPaint &&
                        widget.painter is MatrixPrerequisitePainter,
                  ),
                )
                .painter!
            as MatrixPrerequisitePainter;
    expect(paint.reveal.value, 1);
    hover.value = null;
    await tester.pump();
    expect(paint.reveal.value, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'prerequisite routes preserve code aliases and incoming/outgoing colors',
    (tester) async {
      Future<List<int>> pixel(String highlight) async {
        final painter = MatrixPrerequisitePainter(
          subjects: subjects,
          nodes: nodes,
          highlight: highlight,
          reveal: const AlwaysStoppedAnimation(1),
          color: Colors.red,
          muted: Colors.green,
        );
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), const Size(220, 100));
        final picture = recorder.endRecording();
        final image = await picture.toImage(220, 100);
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final result = bytes!.buffer.asUint8List().sublist(
          (50 * 220 + 100) * 4,
          (50 * 220 + 100) * 4 + 4,
        );
        image.dispose();
        picture.dispose();
        return result;
      }

      await tester.runAsync(() async {
        final outgoing = await pixel('a');
        expect(outgoing[1], greaterThan(outgoing[0]));
        expect(outgoing[3], greaterThan(0));
        final incoming = await pixel('b');
        expect(incoming[0], greaterThan(incoming[1]));
        expect(incoming[3], greaterThan(0));
        expect((await pixel('unrelated'))[3], 0);
      });
    },
  );
}
