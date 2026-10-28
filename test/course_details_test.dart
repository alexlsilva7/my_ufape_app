import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_ufape/core/data_source.dart';
import 'package:my_ufape/core/exceptions/app_exception.dart';
import 'package:my_ufape/core/models.dart';
import 'package:my_ufape/data/parsers/academic_course_parser.dart';
import 'package:my_ufape/data/repositories/academic/academic_data_repository.dart';
import 'package:my_ufape/data/repositories/personal/personal_storage_repository.dart';

import 'repositories_test.dart' show StubCourses, MemoryStorage;

class ControlledCourses extends StubCourses {
  JsonMap document = {
    'course': StubCourses.course,
    'curriculum': [],
    'schedule': [],
  };
  Object? cause;
  final trace = StackTrace.fromString('original transport throw site');
  @override
  Future<JsonMap> getDocument(
    String id, {
    String? semester,
    bool strict = false,
    bool academicOnly = false,
  }) => cause == null ? Future.value(document) : Future.error(cause!, trace);
}

void main() {
  final course = CourseMeta.fromJson(StubCourses.course);

  test(
    'typed details compose profiles, official catalog and Portuguese contents',
    () {
      final details = AcademicCourseParser.parse(
        {
          'curriculum': {
            'activeProfileId': 'P1',
            'export_date': '2026-10-28',
            'profiles': [
              {
                'id': 'P1',
                'subjects': [
                  {'id': 'graph', 'name': 'Visual node'},
                ],
              },
            ],
            'subjects': [
              {
                'id': 'official',
                'code': 'CC01',
                'name': 'Algoritmos',
                'hours': 60,
              },
            ],
          },
          'contents': {
            'disciplinas': [
              {
                'codigo': 'CC1',
                'nome': 'Algoritmos',
                'ementa': 'Ementa oficial',
                'conteudo_programatico': 'Programa completo',
              },
            ],
          },
          'schedule': {
            'disciplines': [
              {'id': 'class', 'name': 'Algoritmos'},
            ],
          },
          'resolvedSemester': '2026.2',
        },
        course,
        '2026.1',
      );
      expect(details.semester, '2026.2');
      expect(details.activeProfileId, 'P1');
      expect(details.catalogExportedAt, DateTime(2026, 10, 28));
      expect(details.profiles.single.id, 'P1');
      expect(details.catalog.single.id, 'official');
      expect(details.catalog.single.desc, 'Ementa oficial');
      expect(
        details.contentFor(details.catalog.single)?.program,
        'Programa completo',
      );
      expect(details.offerings.single.id, 'class');
      expect(() => details.catalog.clear(), throwsUnsupportedError);
    },
  );

  test(
    'legacy list curriculum and embedded schedules are resolved in data layer',
    () {
      final details = AcademicCourseParser.parse(
        {
          'curriculum': [
            {'id': 'legacy', 'name': 'Legado'},
          ],
          'schedules': {
            '2026.1': [],
            '2026.2': [
              {'id': 'new', 'name': 'Nova oferta'},
            ],
          },
          'contents': [],
        },
        course,
        '2025.1',
        offline: true,
      );
      expect(details.semester, '2026.2');
      expect(details.profiles.single.subjects.single.id, 'legacy');
      expect(details.offerings.single.id, 'new');
    },
  );

  test('empty published definitions remain Success, malformed definitions become Failure', () async {
    final repository = ControlledCourses();
    final empty = (await repository.get('bcc')).getOrThrow();
    expect(empty.catalog, isEmpty);
    expect(empty.offerings, isEmpty);
    repository.document = {
      'course': StubCourses.course,
      'curriculum': {'subjects': 'broken'},
    };
    final invalid = await repository.get('bcc');
    expect(invalid.isError(), isTrue);
    expect(
      (invalid.exceptionOrNull() as AppException).cause,
      isA<FormatException>(),
    );
  });

  test(
    'typed repository preserves infrastructure cause and original stack trace',
    () async {
      final repository = ControlledCourses()
        ..cause = StateError('transport rejected');
      final result = await repository.get('bcc');
      final failure = result.exceptionOrNull() as AppException;
      expect(failure.cause, same(repository.cause));
      expect(failure.stackTrace.toString(), repository.trace.toString());
    },
  );

  Future<(AcademicDataRepositoryImpl, PersonalStorageRepositoryImpl)> cached(
    ControlledCourses courses,
    Future<String> Function(String) asset,
  ) async {
    final storage = PersonalStorageRepositoryImpl(MemoryStorage());
    await storage.initialize();
    addTearDown(storage.dispose);
    return (
      AcademicDataRepositoryImpl(courses, storage, DataSource.api, asset),
      storage,
    );
  }

  test('invalid remote data cannot replace a usable cache and degradation retains cause', () async {
    final source = ControlledCourses();
    final (repository, storage) = await cached(
      source,
      (_) async => throw StateError('no asset'),
    );
    expect((await repository.get(course, '2026.1')).isSuccess(), isTrue);
    await storage.flush();
    final saved = storage.read('flutter_cache_bcc_2026.1');
    source.document = {'curriculum': 42};
    final read = (await repository.get(course, '2026.1')).getOrThrow();
    expect(read.offline, isTrue);
    expect(read.failure?.cause, isA<FormatException>());
    expect(storage.read('flutter_cache_bcc_2026.1'), saved);
  });

  test(
    'malformed cache falls through to bundled data with typed contents',
    () async {
      final source = ControlledCourses()..cause = StateError('offline');
      final (repository, storage) = await cached(
        source,
        (_) async => jsonEncode({
          'contents': [
            {'nome': 'Só ementa', 'ementa': 'Descrição'},
          ],
          'schedules': {},
        }),
      );
      storage.seed({'flutter_cache_bcc_2026.1': '{invalid'});
      final read = (await repository.get(course, '2026.1')).getOrThrow();
      expect(read.offline, isTrue);
      expect(read.data.catalog.single.name, 'Só ementa');
      expect(read.failure?.cause, same(source.cause));
    },
  );

  test(
    'unavailable sources return Failure instead of an empty success',
    () async {
      final source = ControlledCourses()..cause = StateError('offline');
      final (repository, _) = await cached(
        source,
        (_) async => throw StateError('no asset'),
      );
      final failure =
          (await repository.get(course, '2026.1')).exceptionOrNull()
              as AppException;
      expect(failure.cause, same(source.cause));
      expect(failure.stackTrace.toString(), source.trace.toString());
    },
  );
}
