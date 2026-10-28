import 'dart:async';
import 'dart:convert';

import 'test_state.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ufape/app/app_repositories.dart';
import 'package:my_ufape/core/app_state.dart';
import 'package:my_ufape/core/data_source.dart';
import 'package:my_ufape/core/exceptions/persistence_exception.dart';
import 'package:my_ufape/core/widgets/persistence_banner.dart';
import 'package:my_ufape/data/repositories/personal/backup_repository.dart';
import 'package:my_ufape/data/repositories/personal/matrix_progress_repository.dart';
import 'package:my_ufape/data/repositories/personal/personal_storage_repository.dart';
import 'package:my_ufape/data/repositories/personal/schedule_plan_repository.dart';
import 'package:my_ufape/domain/repositories/local_storage_repository.dart';
import 'package:my_ufape/features/academic/matrix/widgets/elective_editor.dart';

class DeviceStorage implements LocalStorageRepository {
  final values = <String, String>{};
  final failing = <String>{};
  Completer<void>? gate;
  int failNextWrites = 0;

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);
  @override
  Future<void> write(String key, String value) async {
    await gate?.future;
    if (failing.contains(key) || failNextWrites-- > 0) {
      throw StateError('Device rejected write');
    }
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    await gate?.future;
    if (failing.contains(key)) throw StateError('Device rejected removal');
    values.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DeviceStorage device;
  late PersonalStorageRepository storage;
  final failsToPersist = throwsA(isA<PersistenceException>());

  setUp(() async {
    device = DeviceStorage();
    storage = PersonalStorageRepositoryImpl(device);
    await storage.initialize();
  });
  tearDown(() => storage.dispose());

  test('first writes initialize storage without losing optimistic edits or removals', () async {
    device.values.addAll({
      'grade': 'old',
      'removed': 'old',
      'unchanged': 'keep',
    });
    final lazy = PersonalStorageRepositoryImpl(device);
    addTearDown(lazy.dispose);
    final saving = lazy.write('grade', 'new');
    final removing = lazy.write('removed', null);
    expect(lazy.read('grade'), 'new');
    expect(lazy.read('removed'), isNull);
    await saving;
    await removing;
    await lazy.flush();
    expect(lazy.snapshot, {'grade': 'new', 'unchanged': 'keep'});
    expect(device.values, {'grade': 'new', 'unchanged': 'keep'});
  });

  test(
    'an awaitable write confirms the device, not just the optimistic snapshot',
    () async {
      device.gate = Completer<void>();
      final saving = storage.write('progress', 'new');
      expect(storage.read('progress'), 'new');
      expect(storage.hasPendingChanges, isTrue);
      expect(storage.isSaving, isTrue);
      expect(device.values, isEmpty);
      var finished = false;
      saving.then((_) => finished = true);
      await Future<void>.delayed(Duration.zero);
      expect(finished, isFalse);
      device.gate!.complete();
      await saving;
      expect(device.values['progress'], 'new');
      expect(storage.hasPendingChanges, isFalse);
      expect(storage.isSaving, isFalse);
    },
  );

  test(
    'flush cannot consume a failure or let unrelated writes hide it',
    () async {
      device.failing.add('progress');
      await expectLater(storage.write('progress', 'new'), failsToPersist);
      await expectLater(storage.flush(), failsToPersist);
      await expectLater(storage.flush(), failsToPersist);
      await storage.write('theme', 'dark');
      expect(storage.errorMessage, isNotNull);
      await expectLater(storage.retry(), failsToPersist);
      device.failing.clear();
      await storage.retry();
      expect(device.values, {'progress': 'new', 'theme': 'dark'});
      expect(storage.hasPendingChanges, isFalse);
      expect(storage.errorMessage, isNull);
    },
  );

  test(
    'retry keeps the latest edit and also retries failed removals',
    () async {
      await storage.write('plan', 'old');
      device.failing.add('plan');
      await expectLater(storage.write('plan', 'first edit'), failsToPersist);
      await expectLater(storage.write('plan', 'latest edit'), failsToPersist);
      device.failing.clear();
      await storage.retry();
      expect(device.values['plan'], 'latest edit');
      device.failing.add('plan');
      await expectLater(storage.write('plan', null), failsToPersist);
      expect(storage.read('plan'), isNull);
      device.failing.clear();
      await storage.retry();
      expect(device.values.containsKey('plan'), isFalse);
    },
  );

  test(
    'a queued newer edit supersedes failures without restoring old values',
    () async {
      device.gate = Completer<void>();
      device.failNextWrites = 1;
      final older = storage.write('grade', '7');
      final newer = storage.write('grade', '9');
      final failed = expectLater(older, failsToPersist);
      device.gate!.complete();
      await failed;
      await newer;
      await storage.flush();
      expect(device.values['grade'], '9');
      expect(storage.errorMessage, isNull);
    },
  );

  test(
    'matrix save reports a failed legacy alias and retries the complete intent',
    () async {
      final progress = MatrixProgressRepositoryImpl(storage);
      device.failing.add('bcc_matriz_progress');
      await expectLater(
        progress.save('bcc', 'BCC03', [], (_) => false),
        failsToPersist,
      );
      expect(device.values['bcc_matriz_progress_BCC03'], '[]');
      await expectLater(progress.flush(), failsToPersist);
      device.failing.clear();
      await progress.retry();
      expect(device.values['bcc_matriz_progress'], '[]');
    },
  );

  test(
    'retry persists the failed semester without changing the active course',
    () async {
      final plan = SchedulePlanRepositoryImpl(storage);
      addTearDown(plan.dispose);
      plan.restore('a', '2026.2');
      device.failing.add('schedule_a_2026.2');
      await expectLater(plan.replace([]), failsToPersist);
      plan.restore('b', '2026.1');
      device.failing.clear();
      await plan.retry();
      expect(plan.course, 'b');
      expect(device.values['schedule_a_2026.2'], '[]');
      expect(device.values.containsKey('schedule_b_2026.1'), isFalse);
    },
  );

  test('backup storage failure is explicit and successful rollback restores the old value', () async {
    await storage.write('themePreference', 'light');
    device.failNextWrites = 1;
    final backups = BackupRepositoryImpl(storage);
    await expectLater(
      backups.import('{"themePreference":"dark"}', []),
      failsToPersist,
    );
    expect(storage.read('themePreference'), 'light');
    expect(device.values['themePreference'], 'light');
    await storage.flush();
  });

  test(
    'backup rollback preserves a newer edit queued during the failed import',
    () async {
      await storage.write('themePreference', 'light');
      device.gate = Completer<void>();
      device.failNextWrites = 1;
      final importing = BackupRepositoryImpl(storage)
          .import('{"themePreference":"dark"}', []);
      final failed = expectLater(importing, failsToPersist);
      await Future<void>.delayed(Duration.zero);
      final newer = storage.write('themePreference', 'system');
      device.gate!.complete();
      await failed;
      await newer;
      await storage.flush();
      expect(storage.read('themePreference'), 'system');
      expect(device.values['themePreference'], 'system');
    },
  );

  for (final width in [360.0, 1200.0]) {
    testWidgets('persistence banner exposes recovery at width=$width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      device.failing.add('grade');
      await tester.runAsync(() async {
        // Deliberately optimistic: the queue must observe the rejected Future.
        storage.write('grade', '8');
        await expectLater(storage.flush(), failsToPersist);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PersistenceBanner(storage: storage)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Há alterações não salvas'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        await tester.tap(find.text('Tentar salvar novamente'));
        await expectLater(storage.flush(), failsToPersist);
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('Há alterações não salvas'), findsOneWidget);
      device.failing.clear();
      await tester.runAsync(() async {
        await tester.tap(find.text('Tentar salvar novamente'));
        await storage.flush();
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('Há alterações não salvas'), findsNothing);
      expect(device.values['grade'], '8');
    });
  }

  testWidgets(
    'elective save stays open on failure and retry does not add a duplicate',
    (tester) async {
      late final AppState state;
      await tester.runAsync(() async {
        state = createAppState(
          repositories: AppRepositories(
            source: DataSource.local,
            localStorage: device,
          ),
        );
        await state.initialize();
        await state.selectCourse(
          state.courses.firstWhere((course) => course.id == 'bcc'),
        );
        await state.storage.flush();
      });
      addTearDown(state.dispose);
      state.catalogSubjects.clear();
      final before = state.subjects.length;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showMatrixElectiveEditor(context, state.matrix),
                child: const Text('Adicionar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Optativa de teste');
      await tester.enterText(find.byType(TextField).at(1), '30');
      device.failing.add('bcc_matriz_progress_BCC03');
      await tester.runAsync(() async {
        await tester.tap(find.text('Salvar optativa'));
        await expectLater(state.storage.flush(), failsToPersist);
      });
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Tentar salvar novamente'), findsOneWidget);
      expect(state.subjects.length, before + 1);
      expect(
        tester
            .widgetList<EditableText>(find.byType(EditableText))
            .any((field) => field.focusNode.canRequestFocus),
        isFalse,
      );
      device.failing.clear();
      await tester.runAsync(() async {
        await tester.tap(find.text('Tentar salvar novamente'));
        await state.storage.flush();
      });
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(state.subjects.length, before + 1);
      final saved =
          jsonDecode(device.values['bcc_matriz_progress_BCC03']!) as List;
      expect(
        saved.where((row) => row['additionalElective'] == true),
        hasLength(1),
      );
    },
  );
}
