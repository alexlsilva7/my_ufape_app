import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ufape/core/app_state.dart';
import 'package:my_ufape/features/academic/matrix_screen.dart';
import 'package:my_ufape/core/theme/app_theme.dart';

import 'core_test.dart' as fixture;

Finder _card(String id) => find.byKey(ValueKey('matrix-subject-$id'));
Finder _fill(String id) => find.byKey(ValueKey('matrix-fill-$id'));

Future<AppState> _mount(
  WidgetTester tester, {
  bool reduced = false,
  bool accessible = false,
  bool phone = false,
}) async {
  tester.view.physicalSize = phone
      ? const Size(390, 844)
      : const Size(1440, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final state = await fixture.createState();
  addTearDown(state.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduced,
          accessibleNavigation: accessible,
        ),
        child: child!,
      ),
      home: Scaffold(body: MatrixScreen(state: state)),
    ),
  );
  await tester.pumpAndSettle();
  return state;
}

Color _color(WidgetTester tester, String id) =>
    (tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: _fill(id),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration)
        .color!;

double _opacity(WidgetTester tester, String id) {
  final wrapper = find
      .ancestor(of: _card(id), matching: find.byType(AnimatedOpacity))
      .first;
  return tester
      .widget<FadeTransition>(
        find
            .descendant(of: wrapper, matching: find.byType(FadeTransition))
            .first,
      )
      .opacity
      .value;
}

double _progress(WidgetTester tester) => tester
    .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
    .value!;

void main() {
  testWidgets('status changes interpolate card color and tolerate rapid taps', (
    tester,
  ) async {
    final state = await _mount(tester);
    final subject = state.subjects.first;
    final initial = _color(tester, subject.id);
    await tester.tap(_card(subject.id));
    await tester.pump();
    expect(state.subjectStatus(subject), 'cursando');
    await tester.pump(const Duration(milliseconds: 70));
    expect(_color(tester, subject.id), isNot(initial));
    expect(_color(tester, subject.id), isNot(const Color(0xfffffbeb)));
    await tester.tap(_card(subject.id));
    await tester.pump();
    expect(state.subjectStatus(subject), 'concluido');
    await tester.pump(const Duration(milliseconds: 30));
    await tester.tap(_card(subject.id));
    await tester.pumpAndSettle();
    expect(state.subjectStatus(subject), 'pendente');
    expect(_color(tester, subject.id), initial);
    expect(_card(subject.id), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress animates from its current value when interrupted', (
    tester,
  ) async {
    final state = await _mount(tester);
    expect(_progress(tester), 0);
    state.setSubjectStatus(state.subjects.first, 'concluido');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final middle = _progress(tester);
    expect(middle, inExclusiveRange(0, .2));
    expect(find.text('20.0%'), findsOneWidget);
    state.setSubjectStatus(state.subjects.first, 'pendente');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(_progress(tester), inExclusiveRange(0, middle));
    await tester.pumpAndSettle();
    expect(_progress(tester), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'prerequisite hover fades unrelated cards without replacing them',
    (tester) async {
      await _mount(tester);
      final before = tester.element(_card('slot'));
      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: Offset.zero);
      addTearDown(pointer.removePointer);
      await pointer.moveTo(tester.getCenter(_card('first')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_opacity(tester, 'slot'), inExclusiveRange(.4, 1));
      await tester.pumpAndSettle();
      expect(_opacity(tester, 'slot'), closeTo(.4, .001));
      expect(_opacity(tester, 'second'), 1);
      expect(identical(before, tester.element(_card('slot'))), isTrue);
      await pointer.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(_opacity(tester, 'slot'), 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'search keeps the viewer and zoom while retiring inactive results',
    (tester) async {
      await _mount(tester);
      await tester.tap(find.byTooltip('Aumentar zoom'));
      await tester.pumpAndSettle();
      final viewer = tester.element(find.byType(InteractiveViewer));
      final controller = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      final transform = controller.value.clone();
      final first = tester.element(_card('first'));
      await tester.enterText(find.byType(TextField).first, 'Inteligência');
      await tester.pump();
      expect(_card('second'), findsOneWidget);
      expect(
        find.ancestor(
          of: _card('second'),
          matching: find.byWidgetPredicate(
            (widget) => widget is IgnorePointer && widget.ignoring,
          ),
        ),
        findsWidgets,
      );
      expect(
        find.ancestor(of: _card('second'), matching: find.byType(ExcludeFocus)),
        findsWidgets,
      );
      await tester.pumpAndSettle();
      expect(_card('second'), findsNothing);
      expect(
        identical(viewer, tester.element(find.byType(InteractiveViewer))),
        isTrue,
      );
      expect(controller.value.storage, orderedEquals(transform.storage));
      expect(identical(first, tester.element(_card('first'))), isTrue);
      await tester.tap(find.byTooltip('Limpar pesquisa'));
      await tester.pumpAndSettle();
      expect(_card('second'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('phone view transitions return to an interactive compact list', (
    tester,
  ) async {
    final state = await _mount(tester, phone: true);
    await tester.ensureVisible(find.text('Ver matriz ampla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver matriz ampla'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.text('Ver lista compacta'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
    await tester.ensureVisible(_card('first'));
    await tester.pumpAndSettle();
    await tester.tap(_card('first'));
    await tester.pumpAndSettle();
    expect(state.subjectStatus(state.subjects.first), 'cursando');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rapid filtering revives exiting cards without duplicating them',
    (tester) async {
      await _mount(tester);
      final second = tester.element(_card('second'));
      await tester.enterText(find.byType(TextField).first, 'Inteligência');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 45));
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();
      await tester.pumpAndSettle();
      expect(_card('second'), findsOneWidget);
      expect(identical(second, tester.element(_card('second'))), isTrue);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'elective height changes animate without clipping layout errors',
    (tester) async {
      final state = await _mount(tester);
      final slot = state.subjects.last;
      final element = tester.element(_card(slot.id));
      final node = find.byKey(ValueKey('matrix-node-${slot.id}'));
      final before = tester.getSize(node).height;
      state.setElective(slot, name: 'Computação musical', hours: 30);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      expect(
        tester.getSize(node).height,
        inExclusiveRange(before, before + 32),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.getSize(node).height, closeTo(before + 32, .01));
      expect(identical(element, tester.element(_card(slot.id))), isTrue);
      state.removeElective(state.subjects.last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.getSize(node).height, before);
    },
  );

  testWidgets(
    'zoom buttons accumulate smoothly and wheel input cancels motion',
    (tester) async {
      await _mount(tester);
      final controller = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      await tester.tap(find.byTooltip('Aumentar zoom'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(controller.value.getMaxScaleOnAxis(), inExclusiveRange(1, 1.15));
      await tester.tap(find.byTooltip('Aumentar zoom'));
      await tester.pumpAndSettle();
      expect(
        controller.value.getMaxScaleOnAxis(),
        closeTo(1.15 * 1.15, .00001),
      );
      await tester.tap(find.byTooltip('Restaurar posição'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(controller.value.getMaxScaleOnAxis(), inExclusiveRange(1, 1.3225));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(find.byType(InteractiveViewer)),
          scrollDelta: const Offset(0, 30),
        ),
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      final interrupted = controller.value.clone();
      await tester.pumpAndSettle();
      expect(controller.value.storage, orderedEquals(interrupted.storage));
      await tester.tap(find.byTooltip('Aumentar zoom'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('canceled presses recover without changing academic progress', (
    tester,
  ) async {
    final state = await _mount(tester);
    final card = _card('first');
    final feedback = find
        .ancestor(of: card, matching: find.byType(AnimatedScale))
        .first;
    final pointer = await tester.startGesture(tester.getCenter(card));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 45));
    expect(tester.widget<AnimatedScale>(feedback).scale, lessThan(1));
    await pointer.cancel();
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(feedback).scale, 1);
    expect(state.subjectStatus(state.subjects.first), 'pendente');
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(state.subjectStatus(state.subjects.first), 'cursando');
    expect(tester.takeException(), isNull);
  });

  testWidgets('departing grade fields cannot retain focus or accept input', (
    tester,
  ) async {
    final state = await _mount(tester);
    await tester.tap(find.byTooltip('Detalhes e nota').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concluída').last);
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('grade-first'));
    await tester.enterText(field, '9.4');
    await tester.pumpAndSettle();
    expect(state.grade(state.subjects.first), '9.4');
    await tester.tap(find.text('Pendente').last);
    await tester.pump();
    expect(
      find.ancestor(
        of: field,
        matching: find.byWidgetPredicate(
          (widget) => widget is IgnorePointer && widget.ignoring,
        ),
      ),
      findsWidgets,
    );
    await tester.pumpAndSettle();
    expect(field, findsNothing);
    await tester.tap(find.byTooltip('Fechar detalhes'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'elective mode transitions preserve the search and edited values',
    (tester) async {
      final state = await _mount(tester);
      state.catalogSubjects.add(
        Subject.fromJson(
          fixture.subject(
            'catalog-elective',
            name: 'Inteligência artificial',
            type: 'optativa',
          ),
        ),
      );
      await tester.tap(find.text('Adicionar optativa'));
      await tester.pumpAndSettle();
      final search = find.widgetWithText(TextField, 'Pesquisar optativa');
      await tester.enterText(search, 'artificial');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manual'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Nome da optativa'),
        'Computação musical',
      );
      await tester.tap(find.text('Catálogo'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller!.text, 'artificial');
      await tester.tap(find.text('Manual'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Nome da optativa'),
            )
            .controller!
            .text,
        'Computação musical',
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'phone matrix actions keep help and reset confirmation reachable',
    (tester) async {
      final state = await _mount(tester, phone: true);
      state.setSubjectStatus(state.subjects.first, 'concluido');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ações da matriz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Como usar'));
      await tester.pumpAndSettle();
      expect(find.text('Sua matriz, seu progresso'), findsOneWidget);
      await tester.tap(find.text('Entendi'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ações da matriz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limpar progresso'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(state.subjectStatus(state.subjects.first), 'concluido');
      await tester.tap(find.byTooltip('Ações da matriz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limpar progresso'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Limpar progresso'));
      await tester.pumpAndSettle();
      expect(state.subjectStatus(state.subjects.first), 'pendente');
      expect(tester.takeException(), isNull);
    },
  );

  for (final accessible in [false, true]) {
    testWidgets(
      'matrix motion preference accessible=$accessible applies immediately',
      (tester) async {
        final state = await _mount(
          tester,
          reduced: !accessible,
          accessible: accessible,
        );
        state.setSubjectStatus(state.subjects.first, 'concluido');
        await tester.pump();
        expect(_color(tester, 'first'), const Color(0xffe0faf0));
        expect(_progress(tester), closeTo(.2, .001));
        expect(find.byType(AnimatedSize), findsNothing);
        await tester.tap(find.byTooltip('Aumentar zoom'));
        await tester.pump();
        final controller = tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .transformationController!;
        expect(controller.value.getMaxScaleOnAxis(), closeTo(1.15, .00001));
        await tester.tap(find.byTooltip('Restaurar posição'));
        await tester.pump();
        expect(controller.value.getMaxScaleOnAxis(), 1);
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  }
}
