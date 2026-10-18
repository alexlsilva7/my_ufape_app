import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_ufape/core/api_client.dart';
import 'package:my_ufape/core/app_state.dart';
import 'package:my_ufape/core/theme/app_theme.dart';
import 'package:my_ufape/features/home/home_screen.dart';

Future<AppState> _state({bool selected = true}) async {
  SharedPreferences.setMockInitialValues({});
  final state = AppState(
    api: AcademicApi(
      client: MockClient((_) async => throw Exception('offline')),
    ),
    assetLoader: (path) async => File(path).readAsStringSync(),
  );
  await state.initialize();
  if (selected) {
    await state.selectCourse(
      state.courses.firstWhere((course) => course.id == 'bcc'),
    );
  }
  state.offline = false;
  return state;
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundary,
  String name,
) async {
  if (!const bool.fromEnvironment('HOME_SCREENSHOTS')) return;
  await tester.runAsync(() async {
    final image =
        await (boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('docs/screenshots/home-$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  for (final scenario in [
    ('small-choices', const Size(320, 740), Brightness.light, 1.0, false),
    ('small-selected', const Size(320, 740), Brightness.light, 1.0, true),
    ('phone-dark', const Size(390, 844), Brightness.dark, 1.0, true),
    ('tablet', const Size(600, 960), Brightness.light, 1.0, true),
    ('landscape', const Size(844, 390), Brightness.light, 1.0, true),
    ('large-choices', const Size(320, 740), Brightness.dark, 3.0, false),
    ('large-selected', const Size(390, 844), Brightness.dark, 3.0, true),
    ('desktop', const Size(1440, 1000), Brightness.light, 1.0, true),
  ]) {
    testWidgets('home responsive layout ${scenario.$1}', (tester) async {
      tester.view.physicalSize = scenario.$2;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = await _state(selected: scenario.$5);
      addTearDown(state.dispose);
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
            child: Scaffold(
              body: SafeArea(child: HomeScreen(state: state)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byTooltip('Backups e preferências')).height,
        greaterThanOrEqualTo(48),
      );
      if (scenario.$5 && scenario.$2.width <= 390 && scenario.$4 == 1) {
        final feature = find.byKey(const ValueKey('home-link-/schedule'));
        expect(tester.getSize(feature).height, lessThan(240));
        expect(tester.getRect(feature).top, lessThan(600));
      }
      await tester.runAsync(
        () => precacheImage(
          AssetImage(
            scenario.$3 == Brightness.dark
                ? 'assets/images/my_ufape_logo_azul.png'
                : 'assets/images/my_ufape_logo.png',
          ),
          tester.element(find.byType(HomeScreen)),
        ),
      );
      await tester.pumpAndSettle();
      await _capture(tester, boundary, scenario.$1);
      await tester.ensureVisible(find.text('Repositório no GitHub'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _capture(tester, boundary, '${scenario.$1}-footer');
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('small home cards navigate with the selected course', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = await _state();
    addTearDown(state.dispose);
    const paths = [
      '/schedule',
      '/disciplinas',
      '/matriz',
      '/calendario',
      '/configuracoes',
      '/admin',
    ];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: SafeArea(child: HomeScreen(state: state)),
          ),
        ),
        for (final path in paths)
          GoRoute(
            path: path,
            builder: (context, _) => Scaffold(body: Text('Destino $path')),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: appTheme(Brightness.light),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    for (final path in paths) {
      final target = path == '/configuracoes'
          ? find.byTooltip('Backups e preferências')
          : path == '/admin'
          ? find.byTooltip('Administração')
          : find.byKey(ValueKey('home-link-$path'));
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(find.text('Destino $path'), findsOneWidget);
      if (['/schedule', '/disciplinas', '/matriz'].contains(path)) {
        expect(
          router.routeInformationProvider.value.uri.queryParameters['course'],
          'bcc',
        );
      }
      expect(state.selectedCourse!.id, 'bcc');
      router.go('/');
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
