import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_ufape/data/academic_data_store.dart';
import 'package:my_ufape/data/repositories/document_course_repository.dart';
import 'package:my_ufape/data/repositories/document_repositories.dart';
import 'package:my_ufape/data/repositories/local/local_json_store.dart';
import 'package:my_ufape/data/repositories/supabase/supabase_data_store.dart';
import 'package:my_ufape/domain/repositories/local_storage_repository.dart';

class CrashStorage implements LocalStorageRepository {
  final values = <String, String>{};
  int writes = 0;
  int? crashAt, pauseAt;
  bool crashed = false;
  Completer<void>? resume, reached;
  Future<void> _checkpoint() async {
    if (crashed || ++writes == crashAt) {
      crashed = true;
      throw StateError('Device unavailable');
    }
    if (writes == pauseAt) {
      reached!.complete();
      await resume!.future;
    }
  }

  void crashOn(int operation) {
    writes = 0;
    crashAt = operation;
  }

  void restart() {
    crashAt = null;
    crashed = false;
    writes = 0;
  }

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);
  @override
  Future<void> write(String key, String value) async {
    await _checkpoint();
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    await _checkpoint();
    values.remove(key);
  }
}

LocalJsonStore local(CrashStorage storage) => LocalJsonStore(
  storage: storage,
  assetLoader: (_) async => '{"courses":[]}',
);
DocumentCourseRepository repository(LocalJsonStore store) =>
    DocumentCourseRepository(
      store,
      curricula: DocumentCurriculumRepository(store),
      contents: DocumentContentsRepository(store),
      schedules: DocumentScheduleRepository(store),
    );
Map<String, dynamic> course(String name, {String semester = '2026.1'}) => {
  'id': 'atomic',
  'name': name,
  'semester': semester,
  'curriculum': {
    'subjects': [
      {'id': name, 'profile': name},
    ],
  },
  'schedule': [
    {'id': name, 'profile': name},
  ],
};

void main() {
  for (final crash in [1, 2, 3, 4, 5]) {
    test(
      'save recovers the complete previous set after storage step $crash fails',
      () async {
        final storage = CrashStorage();
        final store = local(storage);
        final courses = repository(store);
        await courses.save(course('old'));
        final before = Map.of(storage.values);
        storage.crashOn(crash);
        await expectLater(courses.save(course('new')), throwsStateError);
        if (crash > 1) {
          expect(storage.values.containsKey(LocalJsonStore.journalKey), isTrue);
          await expectLater(store.select('courses'), throwsStateError);
        } else {
          expect(storage.values, before);
        }
        storage.restart();
        final recovered = await repository(local(storage))
            .getDocument('atomic');
        expect(recovered['course']['name'], 'old');
        expect(recovered['curriculum']['subjects'].single['id'], 'old');
        expect(recovered['schedule'].single['id'], 'old');
        expect(storage.values, before);
      },
    );
  }

  test(
    'failed creation does not leave a registry entry or child documents',
    () async {
      final storage = CrashStorage()..crashOn(4);
      await expectLater(
        repository(local(storage)).save(course('new')),
        throwsStateError,
      );
      storage.restart();
      final restored = local(storage);
      for (final table in ['courses', 'course_curricula', 'course_schedules']) {
        expect(await restored.select(table), isEmpty);
      }
      expect(storage.values, isEmpty);
    },
  );

  test(
    'delete recovers metadata, curriculum, contents and all semesters together',
    () async {
      final storage = CrashStorage();
      final store = local(storage);
      final courses = repository(store);
      await courses.save(course('old'));
      await courses.save(course('second', semester: '2026.2'));
      await DocumentContentsRepository(store).save('atomic', {'subjects': []});
      final before = Map.of(storage.values);
      storage.crashOn(4);
      await expectLater(courses.delete('atomic'), throwsStateError);
      await expectLater(store.select('courses'), throwsStateError);
      storage.restart();
      final recovered = repository(local(storage));
      expect(
        (await recovered.getDocument('atomic'))['course']['hasSchedule'],
        isTrue,
      );
      expect(storage.values, before);
      await recovered.delete('atomic');
      final restarted = local(storage);
      for (final table in [
        'courses',
        'course_curricula',
        'course_contents',
        'course_schedules',
      ]) {
        expect(await restarted.select(table), isEmpty);
      }
    },
  );

  test('readers from another store wait for the complete commit', () async {
    final storage = CrashStorage();
    final courses = repository(local(storage));
    await courses.save(course('old'));
    storage.writes = 0;
    storage.pauseAt = 2;
    storage.reached = Completer<void>();
    storage.resume = Completer<void>();
    final saving = courses.save(course('new'));
    await storage.reached!.future;
    var finished = false;
    final reading = repository(local(storage))
        .getDocument('atomic')
        .then((value) {
          finished = true;
          return value;
        });
    await Future<void>.delayed(Duration.zero);
    expect(finished, isFalse);
    storage.resume!.complete();
    await saving;
    final data = await reading;
    expect(data['course']['name'], 'new');
    expect(data['curriculum']['subjects'].single['id'], 'new');
    expect(data['schedule'].single['id'], 'new');
  });

  test('concurrent semesters and metadata patches preserve each other across local instances', () async {
    final storage = CrashStorage();
    final a = repository(local(storage)), b = repository(local(storage));
    await a.save(course('old'));
    await Future.wait([
      a.save(course('one', semester: '2026.1')),
      b.save(course('two', semester: '2026.2')),
    ]);
    await Future.wait([
      a.updateMetadata('atomic', {'name': 'Renamed', 'shortName': 'AT'}),
      b.updateVisibility('atomic', {'hidden': true}),
    ]);
    final data = await a.getDocument('atomic');
    expect(data['course']['name'], 'Renamed');
    expect(data['course']['hidden'], isTrue);
    expect(data['course']['semesters'], ['2026.1', '2026.2']);
    expect(data['course']['hasCurriculum'], isTrue);
    expect(data['course']['hasSchedule'], isTrue);
  });

  test(
    'invalid batch and malformed journal fail before changing any document',
    () async {
      final storage = CrashStorage();
      final store = local(storage);
      await repository(store).save(course('old'));
      final before = Map.of(storage.values);
      await expectLater(
        repository(store).save({...course('new'), 'schedule': 'invalid'}),
        throwsFormatException,
      );
      expect(storage.values, before);
      await expectLater(
        () => store.writeCourse('atomic', [
          const AcademicMutation.upsert('courses', {
            'id': 'atomic',
            'data': {'name': 'new'},
          }),
          const AcademicMutation.upsert('course_schedules', {
            'course_id': 'atomic',
            'semester': 'bad',
            'data': [],
          }),
        ]),
        throwsFormatException,
      );
      expect(storage.values, before);
      storage.values[LocalJsonStore.journalKey] =
          '{"version":1,"before":{"unrelated_key":null}}';
      final corrupt = Map.of(storage.values);
      await expectLater(store.select('courses'), throwsFormatException);
      expect(storage.values, corrupt);
    },
  );

  test(
    'standalone document writes reconcile flags in the same local transaction',
    () async {
      final storage = CrashStorage();
      final store = local(storage);
      final courses = repository(store);
      await courses.save({'id': 'atomic', 'name': 'Only metadata'});
      expect(
        (await courses.getDocument('atomic'))['course']['hasCurriculum'],
        isFalse,
      );
      await DocumentCurriculumRepository(store)
          .save('atomic', {'subjects': []});
      expect(
        (await courses.getDocument('atomic'))['course']['hasCurriculum'],
        isTrue,
      );
      await store.delete('course_curricula', {'course_id': 'atomic'});
      expect(
        (await courses.getDocument('atomic'))['course']['hasCurriculum'],
        isFalse,
      );
    },
  );

  test('metadata patches cannot recreate a course deleted after client-side lookup', () async {
    final storage = CrashStorage();
    final store = local(storage);
    await repository(store).save(course('old'));
    await repository(store).delete('atomic');
    await expectLater(
      store.writeCourse('atomic', [
        const AcademicMutation.upsert('courses', {
          'id': 'atomic',
          'data': {'name': 'Stale'},
        }, requireExisting: true),
      ]),
      throwsFormatException,
    );
    expect(await store.select('courses'), isEmpty);
  });

  test(
    'remote save uses one RPC and never falls back to partial table writes',
    () async {
      final requests = <http.Request>[];
      final store = SupabaseDataStore(
        url: 'https://test.supabase.co',
        key: 'sb_publishable_test',
        token: () async => 'admin',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{"message":"transaction aborted"}', 409);
        }),
      );
      addTearDown(store.dispose);
      final courses = DocumentCourseRepository(
        store,
        curricula: DocumentCurriculumRepository(store),
        contents: DocumentContentsRepository(store),
        schedules: DocumentScheduleRepository(store),
      );
      await expectLater(courses.save(course('new')), throwsStateError);
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/rest/v1/rpc/commit_academic_course');
      expect(requests.single.headers['Authorization'], 'Bearer admin');
      expect(jsonDecode(requests.single.body)['p_changes'], hasLength(3));
    },
  );
}
