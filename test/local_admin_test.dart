import 'dart:convert';
import 'dart:io';

import 'test_state.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_ufape/app/app_repositories.dart';
import 'package:my_ufape/core/data_source.dart';
import 'package:my_ufape/app/admin_route.dart';
import 'package:my_ufape/features/admin/admin_view.dart';
import 'package:my_ufape/features/admin/widgets/admin_navigation.dart';

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
      final state = createAppState(repositories: repositories);
      await state.initialize();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AdminRoute(state: state)),
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
        (await repositories.courses.getDocument('bcc'))['course']['name'],
        'BCC local editado',
      );
      expect(state.selectedCourse?.name, 'BCC local editado');
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(390, 1050);
      await tester.pumpAndSettle();
      final importTab = find.widgetWithText(ChoiceChip, 'Importar e extrair');
      await tester.scrollUntilVisible(
        importTab,
        150,
        scrollable: find.descendant(
          of: find.byType(AdminNavigation),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(importTab);
      await tester.pumpAndSettle();
      final model = tester.widget<AdminView>(find.byType(AdminView)).viewModel;
      final originalCurriculum = model.curriculum;
      final persistedCurriculum = jsonEncode(
        (await repositories.courses.getDocument('bcc'))['curriculum'],
      );
      final input = find.widgetWithText(TextField, 'Cole o JSON');
      final review = find.text('Revisar substituição');
      final apply = find.widgetWithText(FilledButton, 'Aplicar ao rascunho');
      await tester.enterText(
        input,
        '{"subjects":[{"id":"invalid","name":""}]}',
      );
      await tester.ensureVisible(review);
      await tester.tap(review);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(apply).onPressed, isNull);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(model.curriculum, same(originalCurriculum));

      await tester.enterText(
        input,
        '{"subjects":[{"id":"import-test","name":"Disciplina importada"}]}',
      );
      await tester.ensureVisible(review);
      await tester.tap(review);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(apply).onPressed, isNotNull);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(model.curriculum, same(originalCurriculum));
      await tester.tap(review);
      await tester.pumpAndSettle();
      await tester.tap(apply);
      await tester.pumpAndSettle();
      expect(
        (model.curriculum['subjects'] as List).single['id'],
        'import-test',
      );
      expect(model.hasPendingChanges, isTrue);
      expect(
        jsonEncode(
              (await repositories.courses.getDocument('bcc'))['curriculum'],
            ) ==
            persistedCurriculum,
        isTrue,
        reason: 'Review applies only to the draft until saved',
      );
      expect(tester.takeException(), isNull);

      for (final width in [390.0, 742.0]) {
        tester.view.physicalSize = Size(width, 1050);
        await tester.pumpAndSettle();
        final navigation = find.descendant(
          of: find.byType(AdminNavigation),
          matching: find.byType(Scrollable),
        );
        await tester.drag(navigation, const Offset(1500, 0));
        await tester.pumpAndSettle();
        for (final section in [
          'Configurações',
          'Disciplinas',
          'Estrutura e perfis',
          'Oferta semestral',
          'Importar e extrair',
          'Feedbacks',
        ]) {
          final tab = find.widgetWithText(ChoiceChip, section);
          await tester.scrollUntilVisible(tab, 150, scrollable: navigation);
          await tester.pumpAndSettle();
          await tester.tap(tab);
          await tester.pumpAndSettle();
          expect(tester.widget<ChoiceChip>(tab).selected, isTrue);
          expect(tester.takeException(), isNull, reason: '$section at $width');
        }
      }
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
}
