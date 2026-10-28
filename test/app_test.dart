import 'dart:convert';

import 'test_state.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_ufape/core/api_client.dart';
import 'package:my_ufape/core/app_state.dart';
import 'package:my_ufape/main.dart';
import 'package:my_ufape/features/calendar/calendar_view.dart';
import 'package:my_ufape/features/feedback/feedback_view.dart';
import 'package:go_router/go_router.dart';

import 'core_test.dart' as fixture;

Future<AppState> readyState() async {
  SharedPreferences.setMockInitialValues({});
  final course = {
    'id': 'bcc',
    'name': 'Ciência da Computação',
    'shortName': 'BCC',
    'hasSchedule': true,
    'hasCurriculum': true,
  };
  final state = createAppState(
    api: AcademicApi(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.path == '/api/courses'
                ? {
                    'courses': [course],
                  }
                : {
                    'course': course,
                    'curriculum': {'subjects': []},
                    'schedule': [],
                    'contents': null,
                  },
          ),
          200,
        ),
      ),
    ),
  );
  await state.initialize();
  return state;
}

void main() {
  testWidgets(
    'academic deep links apply course semester and profile and keep URL synchronized',
    (tester) async {
      final state = await fixture.createState();
      await tester.pumpWidget(
        MyUfapeApp(
          state: state,
          initialLocation: '/matriz?course=a&semester=2026.2&profile=P2',
        ),
      );
      await tester.pumpAndSettle();
      expect(state.selectedCourse!.id, 'a');
      expect(state.selectedSemester, '2026.2');
      expect(state.selectedProfile, 'P2');
      await state.selectProfile('P1');
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(AppShell)));
      expect(
        router.routeInformationProvider.value.uri.queryParameters['profile'],
        'P1',
      );
      router.go('/schedule?course=unknown');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
  testWidgets('desktop navigation uses the top menu without a sidebar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = await fixture.createState();
    await tester.pumpWidget(
      MyUfapeApp(state: state, initialLocation: '/disciplinas?course=a'),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Scaffold>(find.byType(Scaffold).first).drawer, isNull);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Sua jornada acadêmica, organizada.'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('top-navigation')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matriz'));
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(AppShell)));
    expect(router.routeInformationProvider.value.uri.path, '/matriz');
    final subject = state.subjects.first;
    await tester.tap(find.byKey(ValueKey('matrix-subject-${subject.id}')));
    await tester.pumpAndSettle();
    expect(state.subjectStatus(subject), 'cursando');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });

  test(
    'calendar month selection uses Sao Paulo and clamps edition boundaries',
    () {
      expect(academicCalendarPage(DateTime.utc(2026, 10, 1, 1)), 8);
      expect(academicCalendarPage(DateTime.utc(2026, 10, 1, 4)), 9);
      expect(academicCalendarPage(DateTime.utc(2024)), 1);
      expect(academicCalendarPage(DateTime.utc(2030)), 16);
      expect(academicCalendarPage(DateTime.utc(2026, 6, 1, 4)), 5);
    },
  );
  for (final size in [const Size(390, 844), const Size(1440, 1000)]) {
    testWidgets('home shell renders without overflow at ${size.width}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = await readyState();
      await tester.pumpWidget(MyUfapeApp(state: state));
      await tester.pumpAndSettle();
      expect(find.text('Selecione seu curso'), findsOneWidget);
      expect(find.text('Ciência da Computação'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Alternar tema: light'));
      await tester.pumpAndSettle();
      expect(state.themeMode, ThemeMode.dark);
      await tester.tap(find.text('Ciência da Computação'));
      await tester.pumpAndSettle();
      expect(find.text('Alterar curso'), findsOneWidget);
      expect(find.text('Horário Letivo'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    });
  }
  testWidgets('feedback rejects a short message without sending a request', (
    tester,
  ) async {
    final state = await readyState();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeedbackView(viewModel: state.feedback, view: '/'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Enviar'));
    await tester.pumpAndSettle();
    expect(find.text('Escreva pelo menos 10 caracteres.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
}
