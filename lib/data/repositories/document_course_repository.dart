import 'course_details_reader.dart';
import '../../core/models.dart';
import '../../domain/repositories/course_repository.dart';
import '../../domain/repositories/curriculum_repository.dart';
import '../../domain/repositories/contents_repository.dart';
import '../../domain/repositories/schedule_repository.dart';
import '../academic_data_store.dart';

class DocumentCourseRepository
    with CourseDetailsReader
    implements CourseRepository {
  DocumentCourseRepository(
    this.store, {
    required this.curricula,
    required this.contents,
    required this.schedules,
  });
  final AcademicDataStore store;
  final CurriculumRepository curricula;
  final ContentsRepository contents;
  final ScheduleRepository schedules;

  static List<String> _strings(dynamic value) =>
      asList(value).map((e) => '$e').toList();
  static List<String> _merged(Iterable<String> a, Iterable<String> b) =>
      {...a, ...b}.toList()..sort();
  Future<List<JsonMap>> _courses() async =>
      (await store.select('courses'))
          .map((row) => {...asMap(row['data']), 'id': row['id']})
          .toList();
  Future<JsonMap?> _find(String id) async {
    const aliases = [
      ['eal', 'engenharia-de-alimentos'],
      ['medicina-veterinaria', 'mvet', 'vet'],
    ];
    final identifiers =
        aliases
            .where((group) => group.contains(id.toLowerCase()))
            .firstOrNull ??
        [id.toLowerCase()];
    return (await _courses())
        .where(
          (course) =>
              identifiers.contains(textOf(course['id']).toLowerCase()) ||
              textOf(course['shortName']).toLowerCase() == id.toLowerCase(),
        )
        .firstOrNull;
  }

  @override
  Future<JsonMap> list() async {
    if (store case AcademicCourseMetadataStore metadata) {
      return {'courses': await metadata.listCourseMetadata()};
    }
    final courses = await _courses();
    final rows = await store.select(
      'course_schedules',
      columns: ['course_id', 'semester'],
    );
    return {
      'courses': [
        for (final course in courses)
          {
            ...course,
            'semesters': _merged(
              _strings(course['semesters']),
              rows
                  .where((row) => row['course_id'] == course['id'])
                  .map((row) => textOf(row['semester'])),
            ),
          },
      ],
    };
  }

  @override
  Future<JsonMap> getDocument(
    String id, {
    String? semester,
    bool strict = false,
    bool academicOnly = false,
  }) async {
    final course = await _find(id);
    if (course == null) throw const FormatException('Curso não encontrado.');
    final courseId = textOf(course['id']);
    final data = await Future.wait<dynamic>([
      curricula.get(courseId),
      contents.get(courseId),
      schedules.semesters(courseId),
    ]);
    final semesters = data[2] as List<String>;
    final available = _merged(_strings(course['semesters']), semesters);
    String? resolved;
    if (semester != null && semesters.contains(semester)) {
      resolved = semester;
    } else if (!(strict && semester != null)) {
      final preferred =
          _strings(course['visibleSemesters']).firstOrNull ??
          available.firstOrNull;
      resolved = semesters.contains(preferred)
          ? preferred
          : semesters.lastOrNull;
    }
    final schedule = resolved == null
        ? null
        : await schedules.get(courseId, resolved);
    return {
      'course': {...course, 'semesters': available},
      'curriculum': data[0],
      'contents': data[1],
      'schedule': schedule?['data'],
      'scheduleExtraction': schedule?['extraction'],
      'scheduleUpdatedAt': schedule?['updated_at'],
      'resolvedSemester': schedule == null ? null : resolved,
    };
  }

  Future<void> _saveMeta(JsonMap data) =>
      store.writeCourse(textOf(data['id']), [
        AcademicMutation.upsert('courses', {
          'id': data['id'],
          'data': data,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, requireExisting: true),
      ]);
  @override
  Future<void> save(JsonMap input) async {
    if ((input['curriculum'] != null &&
            input['curriculum'] is! Map &&
            input['curriculum'] is! List) ||
        (input['schedule'] != null && input['schedule'] is! List)) {
      throw const FormatException('Currículo ou horário inválido.');
    }
    final id = textOf(input['id']).trim();
    final name = textOf(input['name']).trim();
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]*$').hasMatch(id) || name.isEmpty) {
      throw const FormatException(
        'Identificador e nome do curso são obrigatórios.',
      );
    }
    final semester = textOf(input['semester'], '2026.1').replaceAll('_', '.');
    if (input['schedule'] is List &&
        !RegExp(r'^\d{4}\.[12]$').hasMatch(semester)) {
      throw const FormatException('Semestre inválido.');
    }
    var curriculum = input['curriculum'];
    if (curriculum is List) {
      curriculum = <String, dynamic>{'subjects': curriculum};
    }
    if (curriculum != null) {
      curriculum = {
        ...asMap(curriculum),
        'courseName': asMap(curriculum)['courseName'] ?? name,
        'courseShortName':
            asMap(curriculum)['courseShortName'] ?? input['shortName'],
        'export_date':
            asMap(curriculum)['export_date'] ??
            DateTime.now().toUtc().toIso8601String(),
        'subjects': asMap(curriculum)['subjects'] ?? [],
      };
    }
    final profileNames =
        <String>{
          for (final profile in asList(asMap(curriculum)['profiles']))
            textOf(asMap(profile)['id'] ?? asMap(profile)['name']),
          for (final subject in asList(asMap(curriculum)['subjects']))
            textOf(asMap(subject)['profile']),
          for (final subject in asList(input['schedule']))
            textOf(asMap(subject)['profile']),
        }..removeWhere(
          (p) =>
              p.trim().isEmpty ||
              ['optativa', 'sem perfil'].contains(normalized(p)),
        );
    final updatedAt = DateTime.now().toUtc().toIso8601String();
    await store.writeCourse(id, [
      AcademicMutation.upsert('courses', {
        'id': id,
        'data': {
          'id': id,
          'name': name,
          'shortName': textOf(input['shortName'], id.toUpperCase()).trim(),
          if (input['schedule'] is List) 'semesters': [semester],
          if (profileNames.isNotEmpty) 'profiles': profileNames.toList(),
        },
        'updated_at': updatedAt,
      }),
      if (curriculum != null)
        AcademicMutation.upsert('course_curricula', {
          'course_id': id,
          'data': curriculum,
          'updated_at': updatedAt,
        }),
      if (input['schedule'] is List)
        AcademicMutation.upsert('course_schedules', {
          'course_id': id,
          'semester': semester,
          'data': input['schedule'],
          'extraction': input['scheduleExtraction'],
          'updated_at': updatedAt,
        }),
    ]);
  }

  @override
  Future<void> updateMetadata(String id, JsonMap metadata) async {
    final course = await _find(id);
    if (course == null) throw const FormatException('Curso não encontrado.');
    final name = textOf(metadata['name']).trim();
    if (name.isEmpty) throw const FormatException('Nome obrigatório.');
    await _saveMeta({
      'id': course['id'],
      'name': name,
      'shortName': textOf(metadata['shortName']).trim(),
    });
  }

  @override
  Future<void> updateVisibility(String id, JsonMap visibility) async {
    final course = await _find(id);
    if (course == null) throw const FormatException('Curso não encontrado.');
    await _saveMeta({
      'id': course['id'],
      for (final key in [
        'hidden',
        'showSchedule',
        'showDisciplines',
        'showMatriz',
        'visibleSemesters',
      ])
        if (visibility.containsKey(key)) key: visibility[key],
    });
  }

  @override
  Future<void> delete(String id) async {
    final course = await _find(id);
    if (course == null) throw const FormatException('Curso não encontrado.');
    final courseId = textOf(course['id']);
    await store.writeCourse(courseId, [
      AcademicMutation.delete('courses', {'id': courseId}),
    ]);
  }
}
