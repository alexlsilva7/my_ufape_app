import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'test_state.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_ufape/core/api_client.dart';
import 'package:my_ufape/core/app_state.dart';
import 'package:my_ufape/app/app_repositories.dart';
import 'package:my_ufape/data/parsers/academic_course_parser.dart';
import 'package:my_ufape/data/repositories/document_course_repository.dart';
import 'package:my_ufape/data/repositories/document_repositories.dart';
import 'package:my_ufape/data/repositories/local/local_json_store.dart';
import 'package:my_ufape/data/repositories/personal/completion_repository.dart';
import 'package:my_ufape/data/repositories/personal/personal_storage_repository.dart';
import 'package:my_ufape/data/repositories/supabase/supabase_data_store.dart';

import 'core_test.dart' as fixtures;
import 'repositories_test.dart' show MemoryStorage, StubCourses;

class CountStorage extends MemoryStorage {
  final calls = <String>[];
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<void> write(String key, String value) async {
    calls.add(key);
    await gate?.future;
    if (fail) throw StateError('rejected');
    await super.write(key, value);
  }
}

class FixtureCourses extends StubCourses {
  @override
  Future<JsonMap> list() async => {
    'courses': [fixtures.courseA],
  };
  @override
  Future<JsonMap> getDocument(
    String id, {
    String? semester,
    bool strict = false,
    bool academicOnly = false,
  }) async => fixtures.details;
}

DocumentCourseRepository courses(LocalJsonStore store) =>
    DocumentCourseRepository(
      store,
      curricula: DocumentCurriculumRepository(store),
      contents: DocumentContentsRepository(store),
      schedules: DocumentScheduleRepository(store),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('initial local listing loads only registry; course reads never open another asset', () async {
    final reads = <String>[];
    final store = LocalJsonStore(
      storage: MemoryStorage(),
      assetLoader: (path) async {
        reads.add(path);
        if (path.endsWith('courses.json')) {
          return jsonEncode({
            'courses': [
              {
                'id': 'a',
                'semesters': ['2026.1'],
              },
              {
                'id': 'b',
                'semesters': ['2026.1'],
              },
            ],
          });
        }
        if (path.endsWith('/b.json')) {
          throw StateError('Unrelated asset must not load');
        }
        return jsonEncode({
          'curriculum': {'subjects': []},
          'contents': [],
          'schedules': {
            '2026.1': [
              {'id': 'a-class'},
            ],
          },
        });
      },
    );
    final repository = courses(store);
    expect((await repository.list())['courses'], hasLength(2));
    expect(reads, ['assets/data/courses.json']);
    final details = await repository.getDocument(
      'a',
      semester: '2026.1',
      strict: true,
    );
    expect(details['schedule'].single['id'], 'a-class');
    expect(reads, ['assets/data/courses.json', 'assets/data/a.json']);
    await repository.getDocument('a', semester: '2026.1');
    expect(reads, hasLength(2));
  });

  test('bundled semester index includes all actual asset keys', () async {
    final registry =
        jsonDecode(
              await File('assets/data/courses.json').readAsString(),
            )['courses']
            as List;
    for (final course in registry) {
      final asset = jsonDecode(
        await File('assets/data/${course['id']}.json').readAsString(),
      );
      expect(
        asList(course['semesters']),
        containsAll(asMap(asset['schedules']).keys),
        reason: course['id'],
      );
    }
  });

  test('projected local reads retain isolation and invalidate warmed cache after journal recovery', () async {
    final storage = MemoryStorage();
    final before = jsonEncode([
      {
        'id': 'a',
        'data': {'name': 'before'},
      },
      {
        'id': 'b',
        'data': {'name': 'other'},
      },
    ]);
    storage.values['local_data_v1_courses'] = before;
    final store = LocalJsonStore(
      storage: storage,
      assetLoader: (_) async => throw StateError('no seed needed'),
    );
    final rows = await store.select('courses', filters: {'id': 'a'});
    rows.single['data']['name'] = 'external mutation';
    expect(
      (await store.select(
        'courses',
        filters: {'id': 'a'},
      )).single['data']['name'],
      'before',
    );
    expect(await store.select('courses', columns: ['id']), [
      {'id': 'a'},
      {'id': 'b'},
    ]);
    storage.values['local_data_v1_courses'] = jsonEncode([
      {
        'id': 'a',
        'data': {'name': 'partial'},
      },
    ]);
    expect((await store.select('courses')).single['data']['name'], 'partial');
    storage.values[LocalJsonStore.journalKey] = jsonEncode({
      'version': 1,
      'before': {'courses': before},
    });
    expect(
      (await store.select(
        'courses',
        filters: {'id': 'a'},
      )).single['data']['name'],
      'before',
    );
    expect(storage.values.containsKey(LocalJsonStore.journalKey), isFalse);
  });

  test('Supabase semester projection omits the schedule document', () async {
    final store = SupabaseDataStore(
      url: 'https://test.supabase.co',
      key: 'sb_publishable_test',
      client: MockClient((request) async {
        expect(request.url.queryParameters['select'], 'semester');
        expect(request.url.queryParameters['course_id'], 'eq.a');
        return http.Response('[{"semester":"2026.1"}]', 200);
      }),
    );
    addTearDown(store.dispose);
    expect(await DocumentScheduleRepository(store).semesters('a'), ['2026.1']);
  });

  test('completion cache reuses a read-only set and tracks external replacements and courses', () async {
    final storage = PersonalStorageRepositoryImpl(MemoryStorage());
    addTearDown(storage.dispose);
    await storage.initialize();
    final completions = CompletionRepositoryImpl(storage);
    addTearDown(completions.dispose);
    await completions.replace('a', {'CS1'});
    final cached = completions.completedFor('a');
    for (var i = 0; i < 1000; i++) {
      expect(
        completions.isCompleted(
          'a',
          Subject.fromJson({'id': 's', 'code': 'CS1'}),
        ),
        isTrue,
      );
    }
    expect(completions.completedFor('a'), same(cached));
    expect(() => cached.clear(), throwsUnsupportedError);
    storage.seed({'completedDisciplines_a': '["CS2"]'});
    expect(completions.completedFor('a'), {'CS2'});
    expect(completions.completedFor('b'), isEmpty);
    storage.seed({'completedDisciplines_a': '{bad'});
    expect(completions.completedFor('a'), isEmpty);
    await completions.setCompleted(
      'a',
      Subject.fromJson({'id': 's', 'code': 'CS3'}),
      true,
    );
    expect(completions.completedFor('a'), {'CS3'});
  });

  test('only confirmed identical personal values skip writes; failed identical values retry', () async {
    final device = CountStorage();
    final storage = PersonalStorageRepositoryImpl(device);
    addTearDown(storage.dispose);
    await storage.initialize();
    await storage.write('progress', 'old');
    device.calls.clear();
    await storage.write('progress', 'old');
    expect(device.calls, isEmpty);
    device.fail = true;
    await expectLater(storage.write('progress', 'new'), throwsStateError);
    await expectLater(storage.write('progress', 'new'), throwsStateError);
    expect(device.calls, ['progress', 'progress']);
    device.fail = false;
    await storage.retry();
    expect(device.values['progress'], 'new');
    expect(storage.hasPendingChanges, isFalse);
  });

  test('identical pending writes still await device confirmation', () async {
    final device = CountStorage();
    final storage = PersonalStorageRepositoryImpl(device);
    addTearDown(storage.dispose);
    await storage.initialize();
    device.gate = Completer<void>();
    final first = storage.write('progress', 'new');
    var complete = false;
    final second = storage
        .write('progress', 'new')
        .then((_) => complete = true);
    await Future<void>.delayed(Duration.zero);
    expect(complete, isFalse);
    device.gate!.complete();
    await first;
    await second;
    expect(device.values['progress'], 'new');
  });

  test('status command publishes one matrix update and preserves indexed lookup after edits', () async {
    final device = CountStorage()..values['selectedCourse'] = 'a';
    final state = createAppState(
      repositories: AppRepositories(
        api: AcademicApi(
          client: MockClient((_) async => throw StateError('Unexpected HTTP')),
        ),
        courses: FixtureCourses(),
        localStorage: device,
      ),
    );
    addTearDown(state.dispose);
    await state.initialize();
    await state.selectProfile('P1');
    await state.storage.flush();
    device.calls.clear();
    final first = state.subjects.first, dependent = state.subjects[1];
    expect(state.isUnlocked(dependent), isFalse);
    expect(state.missingPrerequisites(dependent).single.id, first.id);
    final originalView = state.subjects;
    expect(state.subjects, same(originalView));
    var updates = 0;
    state.matrix.addListener(() => updates++);
    state.setSubjectStatus(first, 'concluido');
    await state.storage.flush();
    expect(updates, 1);
    expect(
      device.calls.where((key) => key == 'a_matriz_progress_P1'),
      hasLength(1),
    );
    expect(state.isUnlocked(dependent), isTrue);
    expect(state.missingPrerequisites(dependent), isEmpty);
    expect(state.subjects, isNot(same(originalView)));
    state.setGrade(first, '9');
    expect(state.grade(first), '9');
    state.setSubjectStatus(first, 'pendente');
    expect(state.isUnlocked(dependent), isFalse);
    expect(state.grade(first), '');
  });

  test('indexed contents keep earliest source match across name, padded code and equivalence', () {
    final details = AcademicCourseParser.parse(
      {
        'curriculum': {
          'subjects': [
            {'id': 'one', 'code': 'CS01', 'name': 'Name match'},
            {
              'id': 'two',
              'code': 'OTHER',
              'name': 'Other',
              'equivalences': [
                {'code': 'EQ01'},
              ],
            },
            {'id': 'three', 'code': 'CS01', 'name': 'Distinct ID'},
          ],
        },
        'contents': [
          {'nome': 'Name match', 'ementa': 'first by name'},
          {'codigo': 'CS1', 'ementa': 'later by code'},
          {'codigo': 'EQ1', 'ementa': 'equivalent'},
        ],
      },
      CourseMeta.fromJson({'id': 'a'}),
      '2026.1',
    );
    expect(details.catalog.map((subject) => subject.desc), [
      'first by name',
      'equivalent',
      'later by code',
    ]);
  });
}
