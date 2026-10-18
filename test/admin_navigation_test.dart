import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_ufape/core/api_client.dart';
import 'package:my_ufape/core/app_state.dart';
import 'package:my_ufape/features/admin/admin_screen.dart';

void main() {
  testWidgets('untouched login permits leaving without a phantom draft dialog', (
    tester,
  ) async {
    final config = Completer<http.Response>();
    final appState = AppState(
      api: AcademicApi(
        baseUrl: 'https://test.invalid',
        client: MockClient((request) async {
          expect(request.url.path, '/api/admin/config');
          return config.future;
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminScreen(state: appState)),
      ),
    );
    expect(await AdminNavigationGuard.allowLeave(), isTrue);
    expect(find.byType(AlertDialog), findsNothing);

    config.complete(
      http.Response(
        jsonEncode({'authRequired': true, 'authConfigured': true}),
        200,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Entre com uma conta autorizada para administrar os dados acadêmicos.',
      ),
      findsOneWidget,
    );
    expect(await AdminNavigationGuard.allowLeave(), isTrue);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpWidget(const SizedBox());
    appState.dispose();
  });

  for (final malformedCourse in [false, true]) {
    testWidgets(
      'failed ${malformedCourse ? 'course normalization' : 'initial loading'} does not create a draft',
      (tester) async {
        final appState = AppState(
          api: AcademicApi(
            baseUrl: 'https://test.invalid',
            client: MockClient((request) async {
              if (request.url.path == '/api/admin/config') {
                return http.Response('{"authRequired":false}', 200);
              }
              if (!malformedCourse) {
                return http.Response('{"error":"Dados indisponíveis"}', 503);
              }
              if (request.url.path == '/api/courses') {
                return http.Response(
                  '{"courses":[{"id":"bcc","name":"BCC","shortName":"BCC"}]}',
                  200,
                );
              }
              return http.Response(
                jsonEncode({
                  'course': {'id': 'bcc', 'name': 'BCC', 'shortName': 'BCC'},
                  'curriculum': {
                    'subjects': [
                      {'id': 'same', 'code': 'A', 'name': 'A'},
                      {'id': 'same', 'code': 'B', 'name': 'B'},
                    ],
                  },
                }),
                200,
              );
            }),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: AdminScreen(state: appState)),
          ),
        );
        await tester.pumpAndSettle();
        expect(await AdminNavigationGuard.allowLeave(), isTrue);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Rascunho não salvo'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        appState.dispose();
      },
    );
  }

  testWidgets('an edited course still requires an explicit discard decision', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final appState = AppState(
      api: AcademicApi(
        baseUrl: 'https://test.invalid',
        client: MockClient((request) async {
          if (request.url.path == '/api/admin/config') {
            return http.Response('{"authRequired":false}', 200);
          }
          if (request.url.path == '/api/courses') {
            return http.Response(
              '{"courses":[{"id":"bcc","name":"BCC","shortName":"BCC"}]}',
              200,
            );
          }
          return http.Response(
            '{"course":{"id":"bcc","name":"BCC","shortName":"BCC"},"curriculum":{"subjects":[]},"schedule":[]}',
            200,
          );
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminScreen(state: appState)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configurações').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nome do curso'),
      'Novo nome',
    );
    final leaving = AdminNavigationGuard.allowLeave();
    await tester.pumpAndSettle();
    expect(find.text('Alterações não salvas'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(await leaving, isFalse);
    await tester.pumpWidget(const SizedBox());
    appState.dispose();
  });
}
