import 'dart:async';
import 'dart:convert';

import 'test_state.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_ufape/app/app_repositories.dart';
import 'package:my_ufape/core/api_client.dart';
import 'package:my_ufape/core/data_source.dart';
import 'package:my_ufape/domain/repositories/local_storage_repository.dart';

import 'core_test.dart' as fixtures;

class ControlledStorage implements LocalStorageRepository {
  final values = <String, String>{};
  Completer<Map<String, String>>? reading;
  Completer<void>? writing;
  bool failWrites = false;

  @override
  Future<Map<String, String>> readAll() async =>
      reading == null ? Map.of(values) : reading!.future;

  @override
  Future<void> write(String key, String value) async {
    await writing?.future;
    if (failWrites) throw StateError('Storage unavailable');
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async => values.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'theme and grades notify their owners without rebuilding academic context',
    () async {
      final state = await fixtures.createState();
      addTearDown(state.dispose);
      var shared = 0, settings = 0, matrix = 0, timetable = 0;
      state.addListener(() => shared++);
      state.settings.addListener(() => settings++);
      state.matrix.addListener(() => matrix++);
      state.timetable.addListener(() => timetable++);

      state.settings.setThemeMode(ThemeMode.dark);
      expect([shared, settings, matrix, timetable], [0, 1, 0, 0]);

      state.matrix.setGrade(state.matrix.subjects.first, '8,5');
      expect(state.matrix.grade(state.matrix.subjects.first), '8.5');
      expect([shared, settings, matrix, timetable], [0, 1, 1, 0]);
      await state.storage.flush();
    },
  );

  test(
    'plan and completion coordinate both features without notifying routes',
    () async {
      final state = await fixtures.createState();
      addTearDown(state.dispose);
      var shared = 0;
      state.addListener(() => shared++);
      final subject = state.matrix.subjects.first;
      final offering = state.offerings.first;

      expect(state.timetable.toggleDiscipline(offering), isNull);
      expect(state.matrix.subjectStatus(subject), 'cursando');
      state.timetable.setCompleted(offering, true);
      expect(state.timetable.schedule, isEmpty);
      expect(state.matrix.subjectStatus(subject), 'concluido');
      expect(state.matrix.progress.completedCount, 1);

      state.timetable.setCompleted(offering, false);
      expect(state.matrix.subjectStatus(subject), 'pendente');
      expect(state.matrix.progress.completedCount, 0);
      expect(shared, 0);
      await state.storage.flush();
    },
  );

  test('restoring a backup reloads the plan for the already selected course and semester', () async {
    final state = await fixtures.createState();
    addTearDown(state.dispose);
    state.timetable.toggleDiscipline(state.offerings.first);
    final backup = state.settings.exportBackup();
    state.timetable.clearSchedule();
    expect(state.timetable.schedule, isEmpty);

    expect(await state.settings.importBackup(backup), isTrue);
    expect(state.timetable.schedule.single.code, 'CS1');
    expect(state.matrix.subjectStatus(state.matrix.subjects.first), 'cursando');
    await state.storage.flush();
  });

  test(
    'profile import waits for persistence and propagates storage failures',
    () async {
      final storage = ControlledStorage();
      final state = createAppState(
        repositories: AppRepositories(
          source: DataSource.local,
          localStorage: storage,
        ),
      );
      addTearDown(state.dispose);
      await state.initialize();
      await state.selectCourse(state.courses.firstWhere((e) => e.id == 'bcc'));
      await state.storage.flush();
      final exported = state.matrix.exportProfileProgress();
      storage.writing = Completer<void>();
      var completed = false;
      final importing = state.matrix.importProfileProgress(exported).then((
        value,
      ) {
        completed = true;
        return value;
      });
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      storage.writing!.complete();
      expect(await importing, isTrue);

      storage.failWrites = true;
      await expectLater(
        state.matrix.importProfileProgress(
          jsonEncode({
            ...jsonDecode(exported) as Map,
            'accHours': state.accHours + 1,
          }),
        ),
        throwsStateError,
      );
    },
  );

  test(
    'disposal during storage initialization does not notify disposed owners',
    () async {
      final storage = ControlledStorage()
        ..reading = Completer<Map<String, String>>();
      final state = createAppState(
        repositories: AppRepositories(
          source: DataSource.local,
          localStorage: storage,
        ),
      );
      final initializing = state.initialize();
      state.dispose();
      storage.reading!.complete({'themePreference': 'dark'});
      await expectLater(initializing, completes);
    },
  );

  test('backup still excludes academic cache and unknown keys', () async {
    final state = await fixtures.createState();
    addTearDown(state.dispose);
    state.storage.write('unknown_setting', 'private');
    final backup = jsonDecode(state.settings.exportBackup()) as Map;
    expect(
      backup.keys.any((key) => '$key'.startsWith('flutter_cache')),
      isFalse,
    );
    expect(backup.containsKey('unknown_setting'), isFalse);
    await state.storage.flush();
  });

  test(
    'late responses cannot replace the newer course snapshot in offline cache',
    () async {
      var delay = false, offline = false;
      final pending = <Completer<http.Response>>[];
      final state = createAppState(
        repositories: AppRepositories(
          localStorage: ControlledStorage(),
          api: AcademicApi(
            client: MockClient((request) async {
              if (offline) throw StateError('Offline');
              if (request.url.path == '/api/courses') {
                return http.Response(
                  jsonEncode({
                    'courses': [fixtures.courseA],
                  }),
                  200,
                );
              }
              if (!delay) {
                return http.Response(jsonEncode(fixtures.details), 200);
              }
              final response = Completer<http.Response>();
              pending.add(response);
              return response.future;
            }),
          ),
        ),
      );
      addTearDown(state.dispose);
      await state.initialize();
      await state.selectCourse(state.courses.first);
      delay = true;
      final older = state.refresh();
      await Future<void>.delayed(Duration.zero);
      final newer = state.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(pending, hasLength(2));
      pending.last.complete(
        http.Response(
          jsonEncode({
            ...fixtures.details,
            'curriculum': {
              ...fixtures.details['curriculum'] as Map,
              'export_date': '2026-10-28',
            },
          }),
          200,
        ),
      );
      await newer;
      pending.first.complete(
        http.Response(
          jsonEncode({
            ...fixtures.details,
            'curriculum': {
              ...fixtures.details['curriculum'] as Map,
              'export_date': '2026-10-27',
            },
          }),
          200,
        ),
      );
      await older;
      expect(state.courseDetails?.catalogExportedAt, DateTime(2026, 10, 28));

      offline = true;
      await state.refresh();
      expect(state.offline, isTrue);
      expect(state.courseDetails?.catalogExportedAt, DateTime(2026, 10, 28));
      await state.storage.flush();
    },
  );

  test('initialization keeps the unavailable-course error without a saved selection', () async {
    final state = createAppState(
      api: AcademicApi(
        client: MockClient((_) async => http.Response('{"courses":[]}', 200)),
      ),
    );
    addTearDown(state.dispose);
    await state.initialize();
    expect(state.loading, isFalse);
    expect(state.courses, isEmpty);
    expect(state.error, isNotEmpty);
    await state.storage.flush();
  });
}
