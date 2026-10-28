import 'dart:convert';

import 'test_state.dart';

import 'package:file_picker/file_picker.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_ufape/core/api_client.dart';
import 'package:my_ufape/core/app_state.dart';
import 'package:my_ufape/features/academic/catalog/catalog_view.dart';
import 'package:my_ufape/features/academic/matrix/matrix_view.dart';
import 'package:my_ufape/features/academic/schedule/schedule_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core_test.dart' as fixture;

final class JsonTestFile extends PlatformFile {
  JsonTestFile(String text) : bytes = Uint8List.fromList(utf8.encode(text));
  final Uint8List bytes;
  @override
  String get name => 'progresso.json';
  @override
  Uri get uri => Uri.parse('memory:progresso.json');
  @override
  Future<Uint8List> readAsBytes() async => bytes;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ProgressFilePicker extends FilePickerPlatform {
  String? incoming;
  String? exportedName;
  Uint8List? exportedBytes;
  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => incoming == null ? null : JsonTestFile(incoming!);
  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    exportedName = fileName;
    exportedBytes = bytes;
    return Uri.parse('memory:$fileName');
  }
}

ProgressFilePicker useProgressFilePicker() {
  final previous = FilePickerPlatform.instance;
  final picker = ProgressFilePicker();
  FilePickerPlatform.instance = picker;
  addTearDown(() => FilePickerPlatform.instance = previous);
  return picker;
}

Future<void> openProgressMenu(WidgetTester tester, String action) async {
  await tester.ensureVisible(find.byTooltip('Progresso do perfil'));
  await tester.tap(find.byTooltip('Progresso do perfil'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

Future<AppState> createCatalogState() async {
  SharedPreferences.setMockInitialValues({});
  final response = {
    'course': fixture.courseA,
    'curriculum': {
      'subjects': [
        {
          'id': 'official-ai',
          'code': 'OPT1',
          'name': 'Inteligência artificial',
          'type': 'Optativa',
          'period': 0,
          'profile': 'P1',
          'workload': {'total': 60},
          'ementa':
              'Agentes inteligentes, busca e representação de conhecimento.',
        },
      ],
      'profiles': [
        {
          'id': 'P1',
          'name': 'Perfil 1',
          'subjects': [
            fixture.subject(
              'graph-only',
              code: 'GRAPH1',
              name: 'Cartão da matriz',
            ),
          ],
        },
      ],
    },
    'contents': {
      'disciplinas': [
        {
          'codigo': 'OPT1',
          'nome': 'Inteligência artificial',
          'conteudo_programatico':
              'Busca heurística e aprendizagem de máquina.',
        },
        {'codigo': 'CONTENTS1', 'nome': 'Disciplina somente no conteúdo'},
      ],
    },
  };
  final state = createAppState(
    api: AcademicApi(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.path == '/api/courses'
                ? {
                    'courses': [fixture.courseA],
                  }
                : response,
          ),
          200,
        ),
      ),
    ),
  );
  await state.initialize();
  await state.selectCourse(state.courses.first);
  return state;
}

Future<void> mount(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(1440, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final (kind, control) in [
    (PointerDeviceKind.mouse, LogicalKeyboardKey.controlLeft),
    (PointerDeviceKind.trackpad, LogicalKeyboardKey.controlRight),
  ]) {
    testWidgets(
      'matrix ${kind.name} wheel zoom requires Control and never scrolls the page with it',
      (tester) async {
        final state = await fixture.createState();
        addTearDown(state.dispose);
        // Use a short viewport so this compact fixture has scrollable content.
        await mount(
          tester,
          MatrixView(viewModel: state.matrix),
          size: const Size(1440, 640),
        );
        final viewer = find.byType(InteractiveViewer);
        final transform = tester
            .widget<InteractiveViewer>(viewer)
            .transformationController!;
        final page = tester
            .state<ScrollableState>(
              find
                  .ancestor(of: viewer, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        Offset cursor() => tester
            .getRect(viewer)
            .intersect(const Rect.fromLTWH(0, 0, 1440, 1000))
            .center;
        Future<void> wheel(double dy) async {
          await tester.sendEventToBinding(
            PointerScrollEvent(
              kind: kind,
              position: cursor(),
              scrollDelta: Offset(0, dy),
            ),
          );
          await tester.pumpAndSettle();
        }

        final original = transform.value.clone();
        final scrollBefore = page.pixels;
        await wheel(40);
        expect(page.pixels, greaterThan(scrollBefore));
        expect(transform.value.storage, orderedEquals(original.storage));

        final local = cursor() - tester.getTopLeft(viewer);
        final anchor = transform.toScene(local);
        final pageBeforeZoom = page.pixels;
        await tester.sendKeyDownEvent(control);
        try {
          await wheel(-60);
          expect(transform.value.getMaxScaleOnAxis(), greaterThan(1));
          expect(page.pixels, pageBeforeZoom);
          expect(transform.toScene(local).dx, closeTo(anchor.dx, 1e-6));
          expect(transform.toScene(local).dy, closeTo(anchor.dy, 1e-6));
          await wheel(-10000);
          expect(transform.value.getMaxScaleOnAxis(), closeTo(1.6, 1e-6));
          await wheel(10000);
          expect(transform.value.getMaxScaleOnAxis(), closeTo(.35, 1e-6));
          await wheel(40);
          expect(page.pixels, pageBeforeZoom);
        } finally {
          await tester.sendKeyUpEvent(control);
        }
        final afterZoom = transform.value.clone();
        await wheel(-40);
        expect(page.pixels, lessThan(pageBeforeZoom));
        expect(transform.value.storage, orderedEquals(afterZoom.storage));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'matrix browser scale signals, touch pinch and zoom buttons still work',
    (tester) async {
      final state = await fixture.createState();
      addTearDown(state.dispose);
      await mount(tester, MatrixView(viewModel: state.matrix));
      final viewer = find.byType(InteractiveViewer);
      final transform = tester
          .widget<InteractiveViewer>(viewer)
          .transformationController!;
      await tester.ensureVisible(find.byTooltip('Aumentar zoom'));
      await tester.tap(find.byTooltip('Aumentar zoom'));
      await tester.pumpAndSettle();
      expect(transform.value.getMaxScaleOnAxis(), greaterThan(1));
      await tester.tap(find.byTooltip('Restaurar posição'));
      await tester.pumpAndSettle();
      expect(transform.value, Matrix4.identity());

      final center = tester
          .getRect(viewer)
          .intersect(const Rect.fromLTWH(0, 0, 1440, 1000))
          .center;
      final page = tester
          .state<ScrollableState>(
            find.ancestor(of: viewer, matching: find.byType(Scrollable)).first,
          )
          .position;
      final beforeBrowserZoom = page.pixels;
      // Flutter Web converts Ctrl+wheel (and browser trackpad pinches) into
      // PointerScaleEvent rather than PointerScrollEvent.
      await tester.sendEventToBinding(
        PointerScaleEvent(
          kind: PointerDeviceKind.trackpad,
          position: center,
          scale: 1.2,
        ),
      );
      await tester.pumpAndSettle();
      expect(transform.value.getMaxScaleOnAxis(), greaterThan(1));
      expect(page.pixels, beforeBrowserZoom);
      await tester.tap(find.byTooltip('Restaurar posição'));
      await tester.pumpAndSettle();
      final first = await tester.startGesture(
        center - const Offset(30, 0),
        pointer: 11,
      );
      final second = await tester.startGesture(
        center + const Offset(30, 0),
        pointer: 12,
      );
      await tester.pump();
      await first.moveTo(center - const Offset(70, 0));
      await tester.pump();
      await second.moveTo(center + const Offset(70, 0));
      await tester.pump();
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      expect(transform.value.getMaxScaleOnAxis(), greaterThan(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'schedule selections reject conflicting classes and share completion',
    (tester) async {
      final state = await fixture.createState();
      addTearDown(state.dispose);
      await mount(tester, ScheduleView(viewModel: state.timetable));
      await tester.tap(find.text('Oferta one'));
      await tester.pumpAndSettle();
      expect(state.schedule.length, 1);
      expect(find.text('1 disciplina'), findsOneWidget);
      await tester.tap(find.text('Oferta overlap'));
      await tester.pumpAndSettle();
      expect(state.schedule.length, 1);
      expect(find.textContaining('choca com'), findsOneWidget);
      await tester.tap(find.byTooltip('Marcar como concluída').first);
      await tester.pumpAndSettle();
      expect(state.schedule, isEmpty);
      expect(state.isCompleted(state.offerings.first), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('phone schedule switches between offerings and the weekly grid', (
    tester,
  ) async {
    final state = await fixture.createState();
    addTearDown(state.dispose);
    await mount(
      tester,
      ScheduleView(viewModel: state.timetable),
      size: const Size(390, 844),
    );
    await tester.tap(find.text('Oferta one'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Minha grade (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Segunda'), findsOneWidget);
    expect(find.textContaining('OFERTA ONE', findRichText: true), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('catalog search ignores accents and opens curriculum details', (
    tester,
  ) async {
    final state = await createCatalogState();
    addTearDown(state.dispose);
    expect(state.catalogSubjects.map((subject) => subject.code), ['OPT1']);
    await mount(
      tester,
      CatalogView(viewModel: state.catalog),
      size: const Size(390, 844),
    );
    await tester.enterText(find.byType(TextField), 'inteligencia');
    await tester.pumpAndSettle();
    expect(find.text('1 disciplina encontrada'), findsOneWidget);
    await tester.tap(find.text('Inteligência artificial'));
    await tester.pumpAndSettle();
    expect(find.text('Ementa'), findsOneWidget);
    expect(find.text('OPT1'), findsWidgets);
    expect(
      find.text('Agentes inteligentes, busca e representação de conhecimento.'),
      findsOneWidget,
    );
    expect(
      find.text('Busca heurística e aprendizagem de máquina.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('matrix supports a phone viewport and manual elective entry', (
    tester,
  ) async {
    final state = await fixture.createState();
    addTearDown(state.dispose);
    await mount(
      tester,
      MatrixView(viewModel: state.matrix),
      size: const Size(390, 844),
    );
    await tester.ensureVisible(find.text('Adicionar optativa'));
    await tester.tap(find.text('Adicionar optativa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manual'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nome da optativa'),
      'Computação musical',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Carga horária'),
      '30',
    );
    await tester.tap(find.text('Salvar optativa'));
    await tester.pumpAndSettle();
    expect(state.subjects.last.displayName, 'Computação musical');
    expect(state.subjects.last.displayHours, 30);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'matrix details update status immediately and save the final grade',
    (tester) async {
      final state = await fixture.createState();
      addTearDown(state.dispose);
      await mount(
        tester,
        MatrixView(viewModel: state.matrix),
        size: const Size(1440, 1600),
      );
      await tester.ensureVisible(find.byTooltip('Detalhes e nota').first);
      await tester.tap(find.byTooltip('Detalhes e nota').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cursando').last);
      await tester.pumpAndSettle();
      expect(state.subjectStatus(state.subjects.first), 'cursando');
      expect(
        tester
            .widget<SegmentedButton<String>>(
              find.descendant(
                of: find.byType(BottomSheet),
                matching: find.byType(SegmentedButton<String>),
              ),
            )
            .selected,
        {'cursando'},
      );
      await tester.tap(find.text('Concluída').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nota (0 a 10)'),
        '9.4',
      );
      await tester.pumpAndSettle();
      expect(state.grade(state.subjects.first), '9.4');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'matrix exports only the active profile and rejects a mismatched import',
    (tester) async {
      final state = await fixture.createState();
      addTearDown(state.dispose);
      final picker = useProgressFilePicker();
      await state.selectProfile('P1');
      state.setSubjectStatus(state.subjects.first, 'concluido');
      state.setGrade(state.subjects.first, '9.4');
      await mount(tester, MatrixView(viewModel: state.matrix));
      await openProgressMenu(tester, 'Exportar progresso do perfil');
      expect(picker.exportedName, 'a_P1_progresso.json');
      final data = jsonDecode(
        utf8.decode(picker.exportedBytes!),
      ) as Map<String, dynamic>;
      expect(data['course'], 'a');
      expect(data['profileId'], 'P1');
      expect((data['subjects'] as List).first['grade'], '9.4');
      expect(data.containsKey('selectedCourse'), isFalse);
      picker.incoming = jsonEncode({...data, 'profileId': 'P2'});
      await openProgressMenu(tester, 'Importar progresso do perfil');
      expect(
        find.text(
          'Este arquivo não corresponde ao curso a e perfil P1 abertos.',
        ),
        findsOneWidget,
      );
      expect(find.text('Importar progresso do perfil?'), findsNothing);
      expect(state.grade(state.subjects.first), '9.4');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'matrix profile import requires confirmation and restores the selected profile',
    (tester) async {
      final state = await fixture.createState();
      addTearDown(state.dispose);
      final picker = useProgressFilePicker();
      await state.selectProfile('P1');
      state.setSubjectStatus(state.subjects.first, 'concluido');
      state.setGrade(state.subjects.first, '8.5');
      state.setHours(acex: 15, acc: 10);
      picker.incoming = state.exportProfileProgress();
      state.resetProfileProgress();
      await mount(tester, MatrixView(viewModel: state.matrix));
      await openProgressMenu(tester, 'Importar progresso do perfil');
      expect(find.text('Importar progresso do perfil?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(state.grade(state.subjects.first), '');
      expect(state.acexHours, 0);
      await openProgressMenu(tester, 'Importar progresso do perfil');
      await tester.tap(find.text('Importar progresso'));
      await tester.pumpAndSettle();
      expect(state.subjectStatus(state.subjects.first), 'concluido');
      expect(state.grade(state.subjects.first), '8.5');
      expect(state.acexHours, 15);
      expect(state.accHours, 10);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('matrix hours update immediately and remain editable', (
    tester,
  ) async {
    final state = await fixture.createState();
    addTearDown(state.dispose);
    await mount(tester, MatrixView(viewModel: state.matrix));
    final field = find.byKey(const ValueKey('matrix-hours-acex'));
    await tester.ensureVisible(field);
    await tester.enterText(field, '12');
    await tester.pumpAndSettle();
    expect(state.acexHours, 12);
    await tester.enterText(field, '12,5');
    await tester.pumpAndSettle();
    expect(state.acexHours, 12.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'matrix reset confirms before clearing notes electives and hours in the active profile',
    (tester) async {
      final state = await fixture.createState();
      addTearDown(state.dispose);
      await state.selectProfile('P2');
      state.setSubjectStatus(state.subjects.last, 'concluido');
      state.setGrade(state.subjects.last, '7');
      state.setHours(acex: 5, acc: 3);
      await state.selectProfile('P1');
      state.setSubjectStatus(state.subjects.first, 'concluido');
      state.setGrade(state.subjects.first, '9');
      state.setElective(
        state.subjects.last,
        name: 'Optativa escolhida',
        hours: 30,
      );
      state.addElective(name: 'Optativa adicional', hours: 60);
      state.setHours(acex: 20, acc: 10);
      await mount(tester, MatrixView(viewModel: state.matrix));
      await tester.tap(find.text('Limpar progresso'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(state.grade(state.subjects.first), '9');
      expect(state.subjects.last.additionalElective, isTrue);
      await tester.tap(find.text('Limpar progresso'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Limpar progresso'));
      await tester.pumpAndSettle();
      expect(state.grade(state.subjects.first), '');
      expect(
        state.subjects.any(
          (s) => s.additionalElective || s.electiveSelection != null,
        ),
        isFalse,
      );
      expect(state.subjectStatus(state.subjects.first), 'pendente');
      expect(state.acexHours, 0);
      expect(state.accHours, 0);
      await state.selectProfile('P2');
      expect(state.subjectStatus(state.subjects.last), 'concluido');
      expect(state.grade(state.subjects.last), '7');
      expect(state.acexHours, 5);
      expect(state.accHours, 3);
      expect(tester.takeException(), isNull);
    },
  );
}
