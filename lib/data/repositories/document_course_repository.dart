import '../../core/models.dart';
import '../../domain/repositories/course_repository.dart';
import '../../domain/repositories/curriculum_repository.dart';
import '../../domain/repositories/contents_repository.dart';
import '../../domain/repositories/schedule_repository.dart';
import '../academic_data_store.dart';

class DocumentCourseRepository implements CourseRepository {
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
    final courses = await _courses();
    final rows = await store.select('course_schedules');
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
  Future<JsonMap> get(
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

  Future<void> _saveMeta(JsonMap data) => store.upsert('courses', {
    'id': data['id'],
    'data': data,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  });
  @override
  Future<void> save(JsonMap input) async {
    final id = textOf(input['id']).trim();
    final name = textOf(input['name']).trim();
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]*$').hasMatch(id) || name.isEmpty) {
      throw const FormatException(
        'Identificador e nome do curso são obrigatórios.',
      );
    }
    final previous = await _find(id) ?? <String, dynamic>{};
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
          ..._strings(previous['profiles']),
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
    await _saveMeta({
      ...previous,
      'id': id,
      'name': name,
      'shortName': textOf(input['shortName'], id.toUpperCase()).trim(),
      'hasCurriculum': curriculum != null || previous['hasCurriculum'] == true,
      'hasSchedule':
          input['schedule'] is List || previous['hasSchedule'] == true,
      'semesters': _merged(_strings(previous['semesters']), [
        if (input['schedule'] is List) semester,
      ]),
      if (profileNames.isNotEmpty) 'profiles': profileNames.toList(),
    });
    if (curriculum != null) await curricula.save(id, curriculum);
    if (input['schedule'] is List) {
      await schedules.save(
        id,
        semester,
        input['schedule'],
        extraction: input['scheduleExtraction'],
      );
    }
  }

  @override
  Future<void> updateMetadata(String id, JsonMap metadata) async {
    final course = await _find(id);
    if (course == null) throw const FormatException('Curso não encontrado.');
    final name = textOf(metadata['name']).trim();
    if (name.isEmpty) throw const FormatException('Nome obrigatório.');
    await _saveMeta({
      ...course,
      'name': name,
      'shortName': textOf(metadata['shortName']).trim(),
    });
  }

  @override
  Future<void> updateVisibility(String id, JsonMap visibility) async {
    final course = await _find(id);
    if (course == null) throw const FormatException('Curso não encontrado.');
    await _saveMeta({
      ...course,
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
    for (final table in [
      'course_curricula',
      'course_contents',
      'course_schedules',
    ]) {
      await store.delete(table, {'course_id': courseId});
    }
    await store.delete('courses', {'id': courseId});
  }
}
