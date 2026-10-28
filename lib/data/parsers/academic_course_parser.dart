import '../../core/models.dart';
import '../../domain/entities/course_details.dart';

class AcademicCourseParser {
  static CourseDetails parse(
    JsonMap courseDetails,
    CourseMeta course,
    String selectedSemester, {
    bool offline = false,
  }) {
    if (courseDetails['course'] is! Map &&
        !courseDetails.containsKey('curriculum') &&
        !courseDetails.containsKey('schedules') &&
        !courseDetails.containsKey('schedule') &&
        !courseDetails.containsKey('contents')) {
      throw const FormatException('Dados do curso inválidos.');
    }
    for (final key in ['curriculum', 'contents', 'schedule', 'schedules']) {
      final value = courseDetails[key];
      if (value != null && value is! Map && value is! List) {
        throw FormatException('Documento acadêmico inválido: $key');
      }
    }
    final embeddedCourse = asMap(courseDetails['course']);
    if (embeddedCourse['id'] != null && embeddedCourse['id'] != course.id) {
      throw const FormatException('Documento pertence a outro curso.');
    }
    course = CourseMeta.fromJson({...course.toJson(), ...embeddedCourse});
    final curriculumDocument = asMap(courseDetails['curriculum']);
    final contentsDocument = asMap(courseDetails['contents']);
    for (final (document, keys) in [
      (curriculumDocument, ['subjects', 'treeSubjects', 'profiles']),
      (contentsDocument, ['disciplinas', 'subjects']),
      (asMap(courseDetails['schedule']), ['disciplines', 'schedule']),
    ]) {
      for (final key in keys) {
        final items = document[key];
        if (items != null &&
            (items is! List || items.any((item) => item is! Map))) {
          throw FormatException('Coleção acadêmica inválida: $key');
        }
      }
    }
    final embeddedSchedules = asMap(courseDetails['schedules']);
    if (!courseDetails.containsKey('schedule') &&
        embeddedSchedules.isNotEmpty) {
      final semesters = embeddedSchedules.keys.toList()..sort();
      final courseMetadata = asMap(courseDetails['course']);
      final preferred =
          asList(courseMetadata['visibleSemesters']).firstOrNull ??
          asList(courseMetadata['semesters']).firstOrNull;
      final semester = embeddedSchedules.containsKey(selectedSemester)
          ? selectedSemester
          : embeddedSchedules.containsKey(preferred)
          ? preferred.toString()
          : semesters.last;
      final metadata = asMap(
        asMap(courseDetails['scheduleMetadata'])[semester],
      );
      courseDetails = {
        ...courseDetails,
        'schedule': embeddedSchedules[semester],
        'resolvedSemester': semester,
        'scheduleUpdatedAt': metadata['updated_at'],
        'scheduleExtraction': metadata['extraction'],
      };
      if (semester != selectedSemester) {
        selectedSemester = semester;
      }
    }
    final resolved = textOf(courseDetails['resolvedSemester']);
    if (!offline && resolved.isNotEmpty && resolved != selectedSemester) {
      selectedSemester = resolved;
    }

    List<CurriculumProfile> profiles;
    final curriculum = courseDetails['curriculum'];
    final curriculumMap = asMap(curriculum);
    final rawProfiles = asList(curriculumMap['profiles']);
    if (rawProfiles.isNotEmpty) {
      profiles = rawProfiles
          .map((e) => CurriculumProfile.fromJson(asMap(e)))
          .toList();
    } else {
      final tree = asList(curriculumMap['treeSubjects']);
      final rawSubjects = curriculum is List
          ? curriculum
          : tree.isNotEmpty
          ? tree
          : curriculumMap['subjects'];
      profiles = asList(rawSubjects).isEmpty
          ? []
          : [
              CurriculumProfile.fromJson({
                ...curriculumMap,
                'id': course.id,
                'name': course.name,
                'subjects': rawSubjects,
              }),
            ];
    }
    final scheduleData =
        courseDetails['schedule'] ??
        asMap(courseDetails['schedules'])[selectedSemester];
    final offerings = asList(
      scheduleData is Map
          ? scheduleData['disciplines'] ?? scheduleData['schedule']
          : scheduleData,
    ).map((e) => Discipline.fromJson(asMap(e))).toList();
    // The official catalogue retains academic types/workloads. Matrix graph
    // nodes carry visual categories and must not appear as duplicate subjects.
    final official = curriculum is List
        ? curriculum
        : asList(curriculumMap['subjects']);
    final catalog = official.isNotEmpty
        ? official.indexed
              .map(
                (entry) => Subject.fromJson(asMap(entry.$2), index: entry.$1),
              )
              .toList()
        : profiles.expand((p) => p.subjects).toList();
    final contents = courseDetails['contents'];
    final contentItems = asList(
      contents is List
          ? contents
          : asMap(contents)['disciplinas'] ?? asMap(contents)['subjects'],
    );
    if (catalog.isEmpty) {
      catalog.addAll(
        contentItems.indexed.map(
          (entry) => Subject.fromJson(asMap(entry.$2), index: entry.$1),
        ),
      );
    }
    final byCode = <String, (int, JsonMap)>{};
    final byName = <String, (int, JsonMap)>{};
    for (final (position, value) in contentItems.indexed) {
      final content = asMap(value);
      final code = _normalizedCode(
        textOf(content['codigo'] ?? content['code']),
      );
      if (code.isNotEmpty) byCode.putIfAbsent(code, () => (position, content));
      byName.putIfAbsent(
        normalized(textOf(content['nome'] ?? content['name'])),
        () => (position, content),
      );
    }
    JsonMap? contentFor(Subject subject) {
      var first = byName[normalized(subject.name)];
      for (final code in [
        subject.code,
        ...asList(subject.raw['equivalences'])
            .map((value) => asMap(value)['code']?.toString()),
      ].whereType<String>()) {
        final match = byCode[_normalizedCode(code)];
        if (match != null && (first == null || match.$1 < first.$1)) {
          first = match;
        }
      }
      return first?.$2;
    }

    final dedup = <String, Subject>{};
    for (final item in catalog) {
      // Two source entries can legitimately carry the same code (the MVET02
      // snapshot does); retain distinct IDs rather than dropping source data.
      final key = '${item.profile ?? ''}:${item.id}';
      final previous = dedup[key];
      if (previous == null || item.desc.length > previous.desc.length) {
        final detail = contentFor(item);
        dedup[key] = detail == null
            ? item
            : Subject.fromJson({
                ...item.toJson(),
                if (detail['conteudo_programatico'] != null)
                  'conteudo_programatico': detail['conteudo_programatico'],
                if (item.desc.isEmpty &&
                    (detail['ementa'] ?? detail['desc']) != null)
                  'desc': detail['ementa'] ?? detail['desc'],
              }, profile: item.profile);
      }
    }
    return CourseDetails(
      course: course,
      semester: selectedSemester,
      profiles: profiles,
      offerings: offerings,
      catalog: dedup.values.toList(),
      activeProfileId: curriculumMap['activeProfileId']?.toString(),
      catalogExportedAt: DateTime.tryParse(
        textOf(curriculumMap['export_date']),
      ),
      contents: contentItems.map((item) {
        final content = asMap(item);
        return CourseContent(
          code: textOf(content['codigo'] ?? content['code']),
          name: textOf(content['nome'] ?? content['name']),
          description: textOf(content['ementa'] ?? content['desc']),
          program: textOf(content['conteudo_programatico']),
        );
      }).toList(),
    );
  }

  static String _normalizedCode(String? value) => textOf(value)
      .toUpperCase()
      .replaceAllMapped(RegExp(r'([A-Z]+)0+([0-9]+)'), (m) => '${m[1]}${m[2]}');
}
