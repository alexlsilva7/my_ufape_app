import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:my_ufape/core/api_client.dart';
import 'package:my_ufape/core/app_state.dart';
import 'package:my_ufape/features/academic/catalog_screen.dart';
import 'package:my_ufape/app/app_shell.dart';
import 'package:my_ufape/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final scenario in [
    ('desktop', const Size(1280, 1318), Brightness.light, 1.0),
    ('wide', const Size(1920, 1080), Brightness.light, 1.0),
    ('phone', const Size(375, 844), Brightness.light, 1.0),
    ('landscape', const Size(844, 390), Brightness.light, 1.0),
    ('tablet-dark', const Size(834, 1194), Brightness.dark, 1.0),
    ('large-text', const Size(375, 844), Brightness.dark, 3.0),
  ]) {
    testWidgets('catalog reference supports ${scenario.$1}', (tester) async {
      tester.view.physicalSize = scenario.$2;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final state = AppState(
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
      state.offline = false;
      final font = FontLoader('Inter')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File('assets/fonts/Inter.ttf').readAsBytesSync(),
            ),
          ),
        );
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
      final boundary = GlobalKey();
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
              location: '/disciplinas',
              child: CatalogScreen(state: state),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(NavigationRail), findsNothing);
      expect(
        find.text('Ementas, cargas horárias e pré-requisitos do seu curso.'),
        findsNothing,
      );
      expect(find.textContaining('Dados atualizados em'), findsOneWidget);
      expect(find.text('4 cr'), findsWidgets);
      final cards = find.byType(Card);
      if (scenario.$2.width >= 700 && scenario.$4 == 1) {
        final first = tester.getRect(cards.at(0));
        final second = tester.getRect(cards.at(1));
        expect(first.top, second.top);
        expect(second.left, greaterThan(first.right));
        expect(first.width, lessThanOrEqualTo(440));
      }
      if (const bool.fromEnvironment('CATALOG_SCREENSHOTS')) {
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
          await File('docs/screenshots/catalogo-${scenario.$1}.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      if (scenario.$1 == 'desktop') {
        await tester.tap(find.byType(DropdownButtonFormField<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('1º Período').last);
        await tester.pumpAndSettle();
        final firstPeriod = state.catalogSubjects
            .where((s) => s.period == 1)
            .length;
        expect(
          find.text('$firstPeriod disciplinas encontradas'),
          findsOneWidget,
        );
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Optativas').last);
        await tester.pumpAndSettle();
        expect(
          find.text('Nenhuma disciplina encontrada com esses filtros.'),
          findsOneWidget,
        );
        await tester.tap(find.byType(DropdownButtonFormField<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Todos Períodos').last);
        await tester.pumpAndSettle();
        expect(find.byType(Card), findsWidgets);
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Todos Tipos').last);
        await tester.pumpAndSettle();
      }
      // Exercise real catalogue data and the explicit details target after rendering.
      await tester.enterText(find.byType(TextField), 'CCMP3006');
      await tester.pumpAndSettle();
      expect(find.text('1 disciplina encontrada'), findsOneWidget);
      final details = find.byTooltip('Ver detalhes e ementa').first;
      await tester.ensureVisible(details);
      await tester.pumpAndSettle();
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(find.text('Ementa'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
