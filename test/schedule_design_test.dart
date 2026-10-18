import 'dart:io';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_ufape/core/api_client.dart';
import 'package:my_ufape/core/app_state.dart';
import 'package:my_ufape/app/app_shell.dart';
import 'package:my_ufape/core/theme/app_theme.dart';
import 'package:my_ufape/features/academic/schedule_screen.dart';

void main() {
  for (final scenario in [
    ('desktop', const Size(1920, 1320), Brightness.light, 1.0),
    ('phone', const Size(375, 844), Brightness.light, 1.0),
    ('landscape', const Size(844, 390), Brightness.light, 1.0),
    ('dark', const Size(1440, 1100), Brightness.dark, 1.0),
    ('large-text', const Size(375, 844), Brightness.dark, 3.0),
  ]) {
    testWidgets('schedule reference layout ${scenario.$1}', (tester) async {
      tester.view.physicalSize = scenario.$2;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'selectedSemester': '2026.2'});
      final state = AppState(
        api: AcademicApi(
          client: MockClient((request) async {
            if (request.url.path == '/api/courses') {
              throw Exception('offline catalogue');
            }
            return http.Response(
              File('test/fixtures/schedule_bcc_2026_2.json').readAsStringSync(),
              200,
            );
          }),
        ),
        assetLoader: (path) async => File(path).readAsStringSync(),
      );
      await state.initialize();
      addTearDown(state.dispose);
      final reference = jsonDecode(
        File('test/fixtures/schedule_bcc_2026_2.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      await state.selectCourse(
        CourseMeta.fromJson(reference['course'] as Map<String, dynamic>),
      );
      await state.selectSemester('2026.2');
      await state.selectProfile('all');
      for (final query in [
        'jogos digitais',
        'probabilidade',
        'projeto e analise',
        'rede de computadores',
        'interacao humano',
      ]) {
        final offering = state.offerings.firstWhere(
          (d) => normalized(d.name).contains(query),
        );
        expect(state.toggleDiscipline(offering), isNull);
      }
      for (final query in [
        'desenvolvimento de aplicacoes moveis',
        'topicos especiais em midia',
      ]) {
        final match = state.offerings
            .where((d) => normalized(d.name).contains(query))
            .firstOrNull;
        if (match != null) state.setCompleted(match, true);
      }
      final games = state.schedule.firstWhere(
        (d) => normalized(d.name).contains('jogos digitais'),
      );
      final font = FontLoader('Inter')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File('assets/fonts/Inter.ttf').readAsBytesSync(),
            ),
          ),
        );
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File('build/unit_test_assets/fonts/MaterialIcons-Regular.otf')
                  .readAsBytesSync(),
            ),
          ),
        );
      await tester.runAsync(font.load);
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
              location: '/schedule',
              child: ScheduleScreen(state: state),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (scenario.$1 == 'desktop' || scenario.$1 == 'dark') {
        await tester.ensureVisible(
          find.byKey(const ValueKey('schedule-period-0')),
        );
        await tester.tap(find.byKey(const ValueKey('schedule-period-0')));
        await tester.pumpAndSettle();
      }
      if (scenario.$2.width < 1024 || scenario.$4 > 1.5) {
        await tester.tap(find.text('Minha grade (5)'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Segunda'), findsOneWidget);
      expect(find.text('Sábado'), findsNothing);
      final gamesBlock = find.byKey(
        ValueKey('schedule-session-${games.id}-3-14:00 - 18:00'),
      );
      expect(gamesBlock, findsOneWidget);
      expect(tester.getSize(gamesBlock).height, greaterThan(500));
      expect(find.text('18:30 - 20:10'), findsWidgets);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('SCHEDULE_SCREENSHOTS')) {
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
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('docs/screenshots/horarios-${scenario.$1}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      if (scenario.$1 == 'desktop') {
        await tester.tap(find.byKey(const ValueKey('schedule-shift-noite')));
        await tester.pumpAndSettle();
        expect(gamesBlock, findsNothing);
        expect(find.text('13:00 - 14:00'), findsNothing);
        expect(find.text('18:30 - 20:10'), findsWidgets);
        await tester.tap(find.byKey(const ValueKey('schedule-shift-auto')));
        await tester.pumpAndSettle();
        expect(gamesBlock, findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
