import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ufape/core/app_state.dart';
import 'package:my_ufape/core/theme/app_theme.dart';
import 'package:my_ufape/features/academic/academic_context_menu.dart';
import 'package:my_ufape/features/academic/matrix_screen.dart';
import 'package:my_ufape/features/academic/schedule_screen.dart';

import 'core_test.dart' as fixture;

Future<AppState> _mount(
  WidgetTester tester, {
  bool matrix = true,
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
  state.catalogSubjects.addAll([
    Subject.fromJson(
      fixture.subject(
        'elective-ai',
        name: 'Inteligência artificial',
        type: 'optativa',
      ),
    ),
    Subject.fromJson(
      fixture.subject(
        'elective-games',
        name: 'Jogos digitais',
        type: 'optativa',
      ),
    ),
  ]);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: Scaffold(
        body: matrix
            ? MatrixScreen(state: state)
            : ScheduleScreen(state: state),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return state;
}

Finder _matrix(String id) => find.byKey(ValueKey('matrix-subject-$id'));
Finder _offering(String id) => find.byKey(ValueKey('schedule-offering-$id'));
final _session = find.byKey(
  const ValueKey('schedule-session-one-1-07:30 - 09:30'),
);

Future<void> _rightClick(WidgetTester tester, Finder card) async {
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final visible = tester.getRect(card).intersect(Offset.zero & size);
  await tester.tapAt(
    visible.center,
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await tester.pumpAndSettle();
}

void main() {
  if (kIsWeb) {
    testWidgets(
      'web browser menu is restored when the last academic card leaves',
      (tester) async {
        await BrowserContextMenu.enableContextMenu();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AcademicContextMenu(
                actions: [
                  AcademicMenuAction('Detalhes', Icons.info_outline, () {}),
                ],
                child: const SizedBox(width: 200, height: 100),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(BrowserContextMenu.enabled, isFalse);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(BrowserContextMenu.enabled, isTrue);
      },
    );
  }
  for (final phone in [false, true]) {
    testWidgets('elective search receives focus immediately phone=$phone', (
      tester,
    ) async {
      await _mount(tester, phone: phone);
      await tester.ensureVisible(find.text('Definir optativa'));
      await tester.tap(find.text('Definir optativa'));
      await tester.pumpAndSettle();
      final search = find.widgetWithText(TextField, 'Pesquisar optativa');
      final editable = tester.widget<EditableText>(
        find.descendant(of: search, matching: find.byType(EditableText)),
      );
      expect(editable.focusNode.hasFocus, isTrue);
      tester.testTextInput.enterText('Jogos');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller!.text, 'Jogos');
      expect(find.text('Jogos digitais'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'matrix right click selects explicit status without cycling on open',
    (tester) async {
      final state = await _mount(tester);
      for (final entry in [
        ('concluido', 'concluída'),
        ('pendente', 'pendente'),
        ('cursando', 'cursando'),
      ]) {
        final before = state.subjectStatus(state.subjects.first);
        await _rightClick(tester, _matrix('first'));
        expect(state.subjectStatus(state.subjects.first), before);
        await tester.tap(find.text('Marcar como ${entry.$2}'));
        await tester.pumpAndSettle();
        expect(state.subjectStatus(state.subjects.first), entry.$1);
      }
      await _rightClick(tester, _matrix('first'));
      await tester.tap(find.text('Detalhes e nota'));
      await tester.pumpAndSettle();
      expect(find.text('Meu progresso'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'matrix elective menu opens focused editor and reflects the saved choice',
    (tester) async {
      await _mount(tester);
      await _rightClick(tester, _matrix('slot'));
      await tester.tap(find.text('Definir optativa').last);
      await tester.pumpAndSettle();
      final search = find.widgetWithText(TextField, 'Pesquisar optativa');
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: search, matching: find.byType(EditableText)),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      await tester.tap(find.text('Jogos digitais'));
      await tester.tap(find.text('Salvar optativa'));
      await tester.pumpAndSettle();
      await _rightClick(tester, _matrix('slot'));
      expect(find.text('Editar optativa'), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('offering menu enforces conflicts and completion rules', (
    tester,
  ) async {
    final state = await _mount(tester, matrix: false);
    await _rightClick(tester, _offering('one'));
    expect(state.schedule, isEmpty);
    await tester.tap(find.text('Adicionar à grade'));
    await tester.pumpAndSettle();
    expect(state.schedule.single.id, 'one');
    await _rightClick(tester, _offering('overlap'));
    await tester.tap(find.text('Adicionar à grade'));
    await tester.pumpAndSettle();
    expect(state.schedule.single.id, 'one');
    await _rightClick(tester, _offering('one'));
    await tester.tap(find.text('Marcar como concluída'));
    await tester.pumpAndSettle();
    expect(state.isCompleted(state.offerings.first), isTrue);
    expect(state.schedule, isEmpty);
    await _rightClick(tester, _offering('one'));
    expect(
      tester
          .widget<PopupMenuItem<VoidCallback>>(
            find.ancestor(
              of: find.text('Adicionar à grade'),
              matching: find.byType(PopupMenuItem<VoidCallback>),
            ),
          )
          .enabled,
      isFalse,
    );
    await tester.tap(find.text('Marcar como pendente'));
    await tester.pumpAndSettle();
    expect(state.isCompleted(state.offerings.first), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('weekly session menu supports details removal and completion', (
    tester,
  ) async {
    final state = await _mount(tester, matrix: false);
    state.toggleDiscipline(state.offerings.first);
    await tester.pumpAndSettle();
    await _rightClick(tester, _session);
    await tester.tap(find.text('Detalhes e ementa'));
    await tester.pumpAndSettle();
    expect(find.text('Ementa'), findsOneWidget);
    await tester.tap(find.byTooltip('Fechar detalhes'));
    await tester.pumpAndSettle();
    await _rightClick(tester, _session);
    await tester.tap(find.text('Remover da grade'));
    await tester.pumpAndSettle();
    expect(state.schedule, isEmpty);
    state.toggleDiscipline(state.offerings.first);
    await tester.pumpAndSettle();
    await _rightClick(tester, _session);
    await tester.tap(find.text('Marcar como concluída'));
    await tester.pumpAndSettle();
    expect(state.schedule, isEmpty);
    expect(state.isCompleted(state.offerings.first), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keyboard menu stays inside narrow viewport and Escape does not act',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomRight,
              child: AcademicContextMenu(
                actions: [
                  AcademicMenuAction(
                    'Executar ação',
                    Icons.edit,
                    () => calls++,
                  ),
                ],
                child: TextButton(
                  focusNode: focus,
                  onPressed: () {},
                  child: const Text('Cartão'),
                ),
              ),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      final menu = tester.getRect(find.byType(PopupMenuItem<VoidCallback>));
      expect(menu.right, lessThanOrEqualTo(320));
      expect(menu.bottom, lessThanOrEqualTo(480));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(focus.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
