import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_ufape/app/app_repositories.dart';
import 'package:my_ufape/core/app_state.dart';
import 'package:my_ufape/core/data_source.dart';
import 'package:my_ufape/features/admin/admin_screen.dart';

void main() {
  testWidgets(
    'local administration opens without login and saves on the device',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'selectedCourse': 'bcc',
        'selectedSemester': '2026.2',
      });
      final repositories = AppRepositories(
        source: DataSource.local,
        assetLoader: (path) async => File(path).readAsStringSync(),
        apiFactory: (_) =>
            throw StateError('Local must not create an API client'),
        supabaseClientFactory: () =>
            throw StateError('Local must not create a Supabase client'),
      );
      final state = AppState(repositories: repositories);
      await state.initialize();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AdminScreen(state: state)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fonte dos dados: local'), findsOneWidget);
      expect(find.text('E-mail'), findsNothing);
      expect(find.text('Sair'), findsNothing);
      expect(find.text('Migração de dados'), findsNothing);
      await tester.tap(find.text('Configurações').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Nome do curso'),
        'BCC local editado',
      );
      final save = find.text('Salvar neste dispositivo');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        (await repositories.courses.get('bcc'))['course']['name'],
        'BCC local editado',
      );
      expect(state.selectedCourse?.name, 'BCC local editado');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
}
