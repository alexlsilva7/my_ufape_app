import 'dart:io';
import 'dart:convert';

import 'test_state.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_ufape/app/app_repositories.dart';
import 'package:my_ufape/core/app_state.dart';
import 'package:my_ufape/core/data_source.dart';
import 'package:my_ufape/data/repositories/document_course_repository.dart';
import 'package:my_ufape/data/repositories/local/local_course_repository.dart';
import 'package:my_ufape/data/repositories/local/local_json_store.dart';
import 'package:my_ufape/data/repositories/local/shared_preferences_local_storage_repository.dart';

Future<String> asset(String path) => File(path).readAsString();
AppRepositories local() => AppRepositories(
  assetLoader: asset,
  apiFactory: (_) => throw StateError('Local must not access HTTP'),
  supabaseClientFactory: () =>
      throw StateError('Local must not access Supabase'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'local is the default and loads the current semester without a server',
    () async {
      expect(DataSource.environment, DataSource.local);
      expect(() => DataSource.parse('unknown'), throwsArgumentError);
      expect(DataSource.parse(' SUPABASE '), DataSource.supabase);
      SharedPreferences.setMockInitialValues({
        'selectedCourse': 'bcc',
        'selectedSemester': '2026.2',
        'flutter_api_base_url': 'https://unused.invalid',
      });
      final repositories = local();
      expect(repositories.courses, isA<LocalCourseRepository>());
      final state = createAppState(
        repositories: repositories,
        assetLoader: asset,
      );
      addTearDown(state.dispose);
      await state.initialize();
      expect(state.offline, isFalse);
      expect(state.error, isNull);
      expect(state.courses, hasLength(9));
      expect(state.selectedSemester, '2026.2');
      expect(state.offerings, hasLength(47));
      expect(state.filteredOfferings(period: 0), hasLength(9));
      final admin = repositories.createAdminScope();
      addTearDown(admin.dispose);
      expect((await admin.admin.configuration())['authRequired'], isFalse);
      expect(
        (await admin.admin.configuration())['supportsExtraction'],
        isFalse,
      );
      expect(await admin.auth.token(), isNull);
    },
  );

  test('each local document survives a new repository and deletion does not restore seeds', () async {
    var repositories = local();
    final admin = repositories.createAdminScope();
    await admin.courses.save({
      'id': 'offline-course',
      'name': 'Curso offline',
      'shortName': 'OFF',
      'curriculum': {
        'subjects': [
          {'id': 'one', 'name': 'Local', 'profile': 'OFF01'},
        ],
      },
      'semester': '2027.1',
      'schedule': [
        {
          'id': 'local',
          'name': 'Aula local',
          'sessions': [
            {'day': 1, 'time': '08:00 - 10:00'},
          ],
        },
      ],
    });
    final documents = repositories.courses as DocumentCourseRepository;
    await documents.contents.save('offline-course', {
      'disciplinas': [
        {'nome': 'Local', 'ementa': 'Ementa offline'},
      ],
    });
    await admin.courses.updateMetadata('offline-course', {
      'name': 'Nome editado',
      'shortName': 'OFF',
    });
    await admin.courses.updateVisibility('offline-course', {
      'hidden': true,
      'visibleSemesters': ['2027.1'],
    });
    admin.dispose();
    repositories.dispose();

    repositories = local();
    final result = await repositories.courses.getDocument(
      'offline-course',
      semester: '2027.1',
      strict: true,
    );
    expect(result['course']['name'], 'Nome editado');
    expect(result['course']['hidden'], isTrue);
    expect(result['course']['profiles'], contains('OFF01'));
    expect(result['curriculum']['subjects'], hasLength(1));
    expect(result['contents']['disciplinas'].first['ementa'], 'Ementa offline');
    expect(result['schedule'], hasLength(1));
    final missing = await repositories.courses.getDocument(
      'offline-course',
      semester: '2028.1',
      strict: true,
    );
    expect(missing['schedule'], isNull);
    expect(
      (await repositories.courses.getDocument(
        'offline-course',
        semester: '2028.1',
      ))['resolvedSemester'],
      '2027.1',
    );
    await repositories.courses.delete('bcc');
    await repositories.courses.delete('offline-course');
    repositories.dispose();
    final restarted = local();
    addTearDown(restarted.dispose);
    expect(
      asList((await restarted.courses.list())['courses'])
          .map((e) => asMap(e)['id']),
      isNot(contains('bcc')),
    );
    expect(
      () => restarted.courses.getDocument('offline-course'),
      throwsFormatException,
    );
  });

  test(
    'local feedback is persistent, idempotent and only stored on this device',
    () async {
      final repositories = local();
      await repositories.feedback.submit({
        'submissionId': 'local-feedback',
        'category': 'suggestion',
        'message': 'Uma sugestão offline',
        'metadata': {'course': 'bcc'},
      });
      await repositories.feedback.update(
        'local-feedback',
        status: 'reviewing',
        notes: 'Notas locais',
      );
      await repositories.feedback.submit({
        'submissionId': 'local-feedback',
        'message': 'Uma sugestão offline',
      });
      repositories.dispose();
      final restarted = local();
      addTearDown(restarted.dispose);
      final result = await restarted.feedback.list(
        status: 'reviewing',
        course: 'bcc',
      );
      expect(result['total'], 1);
      expect(result['items'].first['internal_notes'], 'Notas locais');
      expect((await restarted.feedback.list(course: 'adm'))['total'], 0);
    },
  );

  test('concurrent JSON changes keep all rows and corrupted JSON is not overwritten', () async {
    final storage = SharedPreferencesLocalStorageRepository();
    final store = LocalJsonStore(storage: storage, assetLoader: asset);
    await Future.wait([
      for (var i = 0; i < 12; i++)
        store.upsert('courses', {
          'id': 'added-$i',
          'data': {'id': 'added-$i'},
        }),
    ]);
    expect(await store.select('courses'), hasLength(21));
    await storage.write('local_data_v1_courses', '{invalid');
    await expectLater(
      store.upsert('courses', {'id': 'bad', 'data': {}}),
      throwsFormatException,
    );
    expect((await storage.readAll())['local_data_v1_courses'], '{invalid');
    await storage.write('local_data_v1_courses', jsonEncode([]));
    await store.upsert('courses', {'id': 'recovered', 'data': {}});
    expect(await store.select('courses'), hasLength(1));
  });
}
