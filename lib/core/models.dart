import 'package:diacritic/diacritic.dart';

typedef JsonMap = Map<String, dynamic>;
JsonMap asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<dynamic> asList(dynamic value) => value is List ? value : [];
String textOf(dynamic value, [String fallback = '']) =>
    value == null ? fallback : value.toString();
double numberOf(dynamic value, [double fallback = 0]) => value is num
    ? value.toDouble()
    : double.tryParse(textOf(value)) ?? fallback;
String normalized(String value) => removeDiacritics(value).trim().toLowerCase();

class CourseMeta {
  final String id, name, shortName;
  final bool hasSchedule,
      hasCurriculum,
      hidden,
      showSchedule,
      showDisciplines,
      showMatriz;
  final List<String> semesters, visibleSemesters, profiles;
  final JsonMap raw;
  CourseMeta.fromJson(JsonMap data)
    : raw = Map.of(data),
      id = textOf(data['id']),
      name = textOf(data['name']),
      shortName = textOf(data['shortName'], textOf(data['name'])),
      hasSchedule = data['hasSchedule'] == true,
      hasCurriculum = data['hasCurriculum'] == true,
      hidden = data['hidden'] == true,
      showSchedule = data['showSchedule'] != false,
      showDisciplines = data['showDisciplines'] != false,
      showMatriz = data['showMatriz'] != false,
      semesters = asList(data['semesters']).map((e) => '$e').toList(),
      visibleSemesters = asList(data['visibleSemesters']).isNotEmpty
          ? asList(data['visibleSemesters']).map((e) => '$e').toList()
          : asList(data['semesters']).map((e) => '$e').toList(),
      profiles = asList(data['profiles']).map((e) => '$e').toList();
  JsonMap toJson() => Map.of(raw);
}

class Session {
  final int day;
  final String time;
  Session({required this.day, required this.time});
  factory Session.fromJson(JsonMap data) =>
      Session(day: numberOf(data['day']).toInt(), time: textOf(data['time']));
  static int? _minute(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
    if (match == null) return null;
    final hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    return hour <= 23 && minute <= 59 ? hour * 60 + minute : null;
  }

  List<int?> get _range =>
      time.split(RegExp(r'\s*[-–—]\s*')).map(_minute).toList();
  int? get startMinutes => _range.length == 2 ? _range.first : null;
  int? get endMinutes => _range.length == 2 ? _range.last : null;
  bool overlaps(Session other) {
    if (day != other.day) return false;
    if (startMinutes == null ||
        endMinutes == null ||
        other.startMinutes == null ||
        other.endMinutes == null) {
      return time.trim() == other.time.trim();
    }
    return startMinutes! < other.endMinutes! &&
        other.startMinutes! < endMinutes!;
  }

  JsonMap toJson() => {'day': day, 'time': time};
}

class Discipline {
  final String id, name;
  final String? code, professor, profile;
  final int? period;
  final List<Session> sessions;
  final JsonMap raw;
  Discipline({
    required this.id,
    required this.name,
    this.code,
    this.professor,
    this.period,
    this.profile,
    required this.sessions,
    JsonMap? raw,
  }) : raw = raw ?? {};
  factory Discipline.fromJson(JsonMap data) {
    var name = textOf(data['name']);
    var profile = textOf(data['profile']).trim();
    if (!data.containsKey('evidence')) {
      // Extrai o perfil do nome da disciplina, caso esteja presente entre parênteses.
      final pattern = RegExp(
        r'\s*\((?:(?:matriz|grade)\s+(?:nova|antiga)\s*[-–:]*\s*|perfil\s*[-–:]*\s*)?([A-Za-z0-9_-]+)\)',
        caseSensitive: false,
      );
      final match = pattern.firstMatch(name);
      if (match != null) {
        if (profile.isEmpty) profile = match[1]!;
        name = name.replaceFirst(pattern, '').trim();
      }
      name = name
          .replaceAll(
            RegExp(
              r'\s*\((?:matriz|grade)\s+(?:nova|antiga)\)',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
    }
    if (['optativa', 'sem perfil'].contains(normalized(profile))) profile = '';
    return Discipline(
      id: textOf(data['id'], textOf(data['code'])),
      name: name,
      code: (data['code'] ?? data['codigo'])?.toString(),
      professor: data['professor']?.toString(),
      period: data['period'] == null ? null : numberOf(data['period']).toInt(),
      profile: profile,
      sessions: asList(data['sessions'])
          .map((e) => Session.fromJson(asMap(e)))
          .toList(),
      raw: Map.of(data),
    );
  }
  JsonMap toJson() => {
    ...raw,
    'id': id,
    'name': name,
    'code': code,
    'professor': professor,
    'period': period,
    'profile': profile,
    'sessions': sessions.map((e) => e.toJson()).toList(),
  };
}

class ElectiveSelection {
  final String source, name;
  final String? subjectId, code, desc;
  final double hours;
  ElectiveSelection({
    required this.name,
    required this.hours,
    this.source = 'manual',
    this.subjectId,
    this.code,
    this.desc,
  });
  static ElectiveSelection? parse(dynamic value) {
    final data = asMap(value);
    final name = textOf(data['name']).trim();
    final hours = numberOf(data['hours']);
    if (!['catalog', 'manual'].contains(data['source']) ||
        name.isEmpty ||
        !hours.isFinite ||
        hours <= 0) {
      return null;
    }
    return ElectiveSelection(
      name: name,
      hours: hours,
      source: data['source'],
      subjectId: data['subjectId']?.toString(),
      code: data['code']?.toString(),
      desc: data['desc']?.toString(),
    );
  }

  String get identity => code?.trim().isNotEmpty == true
      ? 'code:${normalized(code!)}'
      : 'name:${normalized(name)}';
  JsonMap toJson() => {
    'source': source,
    'name': name,
    'hours': hours,
    if (subjectId != null) 'subjectId': subjectId,
    if (code != null) 'code': code,
    if (desc != null) 'desc': desc,
  };
}

class Subject {
  final String id, name, type, desc;
  final String? code, profile;
  final int? period;
  final double hours;
  final List<String> prereqs;
  final JsonMap raw;
  Subject({
    required this.id,
    required this.name,
    this.code,
    this.profile,
    this.period,
    this.hours = 0,
    this.type = 'outros',
    this.desc = '',
    this.prereqs = const [],
    JsonMap? raw,
  }) : raw = raw ?? {};
  factory Subject.fromJson(JsonMap data, {String? profile, int index = 0}) {
    final workload = asMap(data['workload']);
    final requirements = data.containsKey('prereqs')
        ? data['prereqs']
        : data['prerequisites'];
    return Subject(
      id: textOf(
        data['id'],
        textOf(data['code'] ?? data['codigo'], 'subject_$index'),
      ),
      name: textOf(
        data['name'],
        textOf(data['nome'], 'Disciplina ${index + 1}'),
      ),
      code: (data['code'] ?? data['codigo'])?.toString(),
      profile: profile ?? data['profile']?.toString(),
      period: numberOf(data['period']).toInt(),
      hours: numberOf(
        data['hours'] ?? workload['total'] ?? workload['total_hours'],
      ),
      type: textOf(data['type'], textOf(data['tipo'], 'outros')),
      desc: textOf(data['desc'], textOf(data['ementa'])),
      prereqs: asList(requirements)
          .map(
            (e) => e is String
                ? e
                : textOf(
                    asMap(e)['id'] ?? asMap(e)['code'] ?? asMap(e)['name'],
                  ),
          )
          .where((e) => e.isNotEmpty)
          .toList(),
      raw: Map.of(data),
    );
  }
  bool get isCatalogElective =>
      isElective || raw['period'] == 0 || raw['period'] == '0';
  bool get isElective => [
    type,
    raw['academicType'],
    profile,
    raw['period'],
  ].any((e) => normalized(textOf(e)).contains('optativ'));
  bool get isGenericElective =>
      isElective &&
      RegExp(r'^(?:disciplina\s+)?optativ[ao](?:\s+(?:[ivxlcdm]+|\d+))?$')
          .hasMatch(normalized(name));
  bool get additionalElective => raw['additionalElective'] == true;
  ElectiveSelection? get electiveSelection =>
      ElectiveSelection.parse(raw['electiveSelection']);
  String get displayName => electiveSelection?.name ?? name;
  double get displayHours => electiveSelection?.hours ?? hours;
  String? get displayCode => electiveSelection?.code ?? code;
  JsonMap toJson() => {
    ...raw,
    'id': id,
    'name': name,
    'code': code,
    'profile': profile,
    'period': period,
    'hours': hours,
    'type': type,
    'prereqs': prereqs,
    'desc': desc,
  };
}

class CurriculumProfile {
  final String id, name;
  final List<Subject> subjects;
  final double totalHours, acexHours, accHours, optativeHours, mandatoryHours;
  final JsonMap raw;
  CurriculumProfile.fromJson(
    JsonMap data, {
    String fallbackId = 'curriculum',
    String fallbackName = 'Matriz curricular',
  }) : id = textOf(data['id'], fallbackId),
       name = textOf(data['name'], textOf(data['description'], fallbackName)),
       totalHours = numberOf(
         data['totalHours'] ?? asMap(data['requisitos'])['total'],
       ),
       acexHours = numberOf(
         data['acexHours'] ?? asMap(data['requisitos'])['acex_extensao'],
       ),
       accHours = numberOf(
         data['accHours'] ?? asMap(data['requisitos'])['acc_complementar'],
       ),
       optativeHours = numberOf(
         data['optativeHours'] ?? asMap(data['requisitos'])['optativas'],
       ),
       mandatoryHours = numberOf(
         data['mandatoryHours'] ?? asMap(data['requisitos'])['obrigatorias'],
       ),
       subjects = mapProfileSubjects(
         asList(data['subjects']),
         textOf(data['id'], fallbackId),
       ),
       raw = Map.of(data);
}

/// Matrix prerequisite edges use IDs even when a source references a code/name.
List<Subject> mapProfileSubjects(List<dynamic> sources, String profile) {
  final subjects = sources.indexed
      .map(
        (entry) => Subject.fromJson(
          asMap(entry.$2),
          profile: profile,
          index: entry.$1,
        ),
      )
      .toList();
  final references = <String, String>{};
  for (final subject in subjects) {
    for (final ref in [subject.id, subject.code, subject.name]) {
      if (ref != null && ref.trim().isNotEmpty) {
        references[normalized(ref)] = subject.id;
      }
    }
  }
  return subjects
      .map(
        (subject) => Subject.fromJson({
          ...subject.toJson(),
          'prereqs': subject.prereqs
              .map((ref) => references[normalized(ref)] ?? ref)
              .toList(),
        }, profile: profile),
      )
      .toList();
}

class MatrixProgress {
  final double doneHours,
      totalHours,
      mandatoryHours,
      optativeHours,
      acexHours,
      accHours;
  final int completedCount, totalCount;
  const MatrixProgress({
    this.doneHours = 0,
    this.totalHours = 0,
    this.mandatoryHours = 0,
    this.optativeHours = 0,
    this.acexHours = 0,
    this.accHours = 0,
    this.completedCount = 0,
    this.totalCount = 0,
  });
  double get percentage =>
      totalHours > 0 ? (doneHours / totalHours * 100).clamp(0, 100) : 0;
  double get remainingHours =>
      (totalHours - doneHours).clamp(0, double.infinity);
}
