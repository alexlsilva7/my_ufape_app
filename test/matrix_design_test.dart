import 'dart:io';
import 'dart:ui' as ui;

import 'test_state.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ufape/features/academic/matrix/matrix_view.dart';
import 'package:my_ufape/app/app_shell.dart';
import 'package:my_ufape/core/theme/app_theme.dart';

import 'package:my_ufape/core/api_client.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final scenario in [
    ('desktop', const Size(1440, 1100), Brightness.light, 1.0),
    ('reference', const Size(2480, 1320), Brightness.light, 1.0),
    ('phone', const Size(375, 844), Brightness.light, 1.0),
    ('phone-wide-small', const Size(320, 740), Brightness.light, 1.0),
    ('phone-wide-dark', const Size(390, 844), Brightness.dark, 1.0),
    ('phone-wide-600', const Size(600, 960), Brightness.dark, 1.0),
    ('phone-wide-text', const Size(390, 844), Brightness.dark, 2.0),
    ('landscape', const Size(844, 390), Brightness.light, 1.0),
    ('tablet-dark', const Size(834, 1194), Brightness.dark, 1.0),
    ('large-text', const Size(375, 844), Brightness.dark, 3.0),
  ]) {
    testWidgets('matrix React layout supports ${scenario.$1}', (tester) async {
      tester.view.physicalSize = scenario.$2;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final state = createAppState(
        api: AcademicApi(
          client: MockClient((_) async => throw Exception('offline')),
        ),
        assetLoader: (path) async => File(path).readAsStringSync(),
      );
      await state.initialize();
      addTearDown(state.dispose);
      await state.selectCourse(
        state.courses.firstWhere((course) => course.id == 'bcc'),
      );
      if (scenario.$1 == 'reference') {
        await state.selectProfile('BCC02');
        for (final subject in state.subjects.where(
          (s) => (s.period ?? 0) <= 3,
        )) {
          state.setSubjectStatus(subject, 'concluido');
        }
        for (final subject
            in state.subjects.where((s) => (s.period ?? 0) == 4).take(2)) {
          state.setSubjectStatus(subject, 'cursando');
        }
      }
      state.setSubjectStatus(state.subjects.first, 'concluido');
      state.setGrade(state.subjects.first, '9.0');
      if (scenario.$1 != 'reference') {
        state.setSubjectStatus(state.subjects[1], 'cursando');
      }
      if (scenario.$1 == 'large-text') {
        final slot = state.subjects.firstWhere((s) => s.isGenericElective);
        state.setElective(
          slot,
          name:
              'Tópicos especiais em engenharia de software e aplicações móveis',
          hours: 60,
        );
      }
      state.offline = false;
      final boundary = GlobalKey();
      final fontData = ByteData.sublistView(
        File('assets/fonts/Inter.ttf').readAsBytesSync(),
      );
      final font = FontLoader('Inter')..addFont(Future.value(fontData));
      await tester.runAsync(font.load);
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File('build/unit_test_assets/fonts/MaterialIcons-Regular.otf')
                  .readAsBytesSync(),
            ),
          ),
        );
      await tester.runAsync(icons.load);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(scenario.$3),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scenario.$4),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: RepaintBoundary(
            key: boundary,
            child: AppShell(
              state: state,
              location: '/matriz',
              child: MatrixView(viewModel: state.matrix),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final widePhone = scenario.$1.startsWith('phone-wide');
      if (widePhone) {
        await tester.ensureVisible(find.text('Ver matriz ampla'));
        await tester.tap(find.text('Ver matriz ampla'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      expect(find.text('SUA JORNADA ACADÊMICA'), findsNothing);
      expect(find.text('RESUMO DE REQUISITOS E CARGA HORÁRIA'), findsOneWidget);
      if (!widePhone && (scenario.$2.width < 700 || scenario.$4 > 1.5)) {
        expect(find.byType(InteractiveViewer), findsNothing);
      } else {
        expect(find.byType(InteractiveViewer), findsOneWidget);
      }
      if (widePhone) {
        final first = find.byKey(
          ValueKey('matrix-subject-${state.subjects.first.id}'),
        );
        expect(tester.getSize(first).width, greaterThanOrEqualTo(220));
        expect(tester.getSize(first).height, greaterThanOrEqualTo(144));
        expect(find.byTooltip('Aumentar zoom'), findsOneWidget);
      }
      if (const bool.fromEnvironment('MATRIX_SCREENSHOTS')) {
        await tester.runAsync(
          () => precacheImage(
            AssetImage(
              scenario.$3 == Brightness.dark
                  ? 'assets/images/my_ufape_logo_azul.png'
                  : 'assets/images/my_ufape_logo.png',
            ),
            tester.element(find.byType(AppShell)),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('docs/screenshots/matriz-${scenario.$1}.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      if (widePhone) {
        if (scenario.$1 == 'phone-wide-small') {
          final viewer = find.byType(InteractiveViewer);
          final controller = tester
              .widget<InteractiveViewer>(viewer)
              .transformationController!;
          final beforePan = controller.value.entry(0, 3);
          final firstCard = find.byKey(
            ValueKey('matrix-subject-${state.subjects.first.id}'),
          );
          await tester.ensureVisible(firstCard);
          await tester.pumpAndSettle();
          await tester.timedDragFrom(
            tester.getCenter(firstCard),
            const Offset(-100, 0),
            const Duration(milliseconds: 400),
          );
          await tester.pumpAndSettle();
          expect(controller.value.entry(0, 3), lessThan(beforePan));
          final scrollable = find
              .descendant(
                of: find.byKey(const ValueKey('matrix-page-scroll')),
                matching: find.byType(Scrollable),
              )
              .first;
          final page = tester.state<ScrollableState>(scrollable).position;
          final beforeScroll = page.pixels;
          await tester.timedDragFrom(
            tester.getCenter(firstCard),
            const Offset(0, -140),
            const Duration(milliseconds: 400),
          );
          await tester.pumpAndSettle();
          expect(page.pixels, greaterThan(beforeScroll));
        }
        final lastPeriod = state.subjects
            .map((s) => s.period ?? 0)
            .reduce((a, b) => a > b ? a : b);
        final jump = find.byKey(ValueKey('matrix-period-jump-$lastPeriod'));
        await tester.ensureVisible(jump);
        await tester.tap(jump);
        await tester.pumpAndSettle();
        final lastSubject = state.subjects.firstWhere(
          (s) => s.period == lastPeriod,
        );
        final lastCard = tester.getRect(
          find.byKey(ValueKey('matrix-subject-${lastSubject.id}')),
        );
        final viewport = tester.getRect(find.byType(InteractiveViewer));
        expect(lastCard.right, lessThanOrEqualTo(viewport.right + 1));
        expect(lastCard.right, greaterThan(viewport.left));
        await tester.ensureVisible(find.byTooltip('Aumentar zoom'));
        await tester.tap(find.byTooltip('Aumentar zoom'));
        await tester.pumpAndSettle();
        final transform = tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .transformationController!;
        final zoom = transform.value.getMaxScaleOnAxis();
        final search = find.byType(TextField).first;
        await tester.ensureVisible(search);
        await tester.enterText(search, state.subjects.first.displayName);
        await tester.pumpAndSettle();
        final filtered = tester.getRect(
          find.byKey(ValueKey('matrix-subject-${state.subjects.first.id}')),
        );
        final filteredViewport = tester.getRect(find.byType(InteractiveViewer));
        expect(filtered.left, greaterThanOrEqualTo(filteredViewport.left - 1));
        expect(filtered.left, lessThan(filteredViewport.right));
        expect(transform.value.getMaxScaleOnAxis(), closeTo(zoom, .00001));
        await tester.enterText(search, '');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Ver lista compacta'));
        await tester.tap(find.text('Ver lista compacta'));
        await tester.pumpAndSettle();
        expect(find.byType(InteractiveViewer), findsNothing);
      }
      await tester.ensureVisible(find.text('Horas obrigatórias concluídas'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
