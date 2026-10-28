import 'dart:convert';

import '../core/models.dart';
import 'academic_data_store.dart';

/// An immutable wire snapshot, validated before touching any document.
class AcademicBatch {
  AcademicBatch(this.courseId, List<AcademicMutation> operations)
    : changes = asList(
        jsonDecode(jsonEncode(operations.map((e) => e.toJson()).toList())),
      ).map(asMap).toList() {
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]*$').hasMatch(courseId) ||
        changes.isEmpty ||
        changes.length > 16) {
      throw const FormatException('Lote acadêmico inválido.');
    }
    for (final change in changes) {
      final table = change['table'];
      if (!tables.contains(table)) {
        throw const FormatException('Documento acadêmico inválido.');
      }
      final idKey = table == 'courses' ? 'id' : 'course_id';
      if (change['action'] == 'upsert') {
        final row = asMap(change['row']);
        if (row[idKey] != courseId ||
            row['data'] == null ||
            (table == 'courses' && row['data'] is! Map) ||
            (table == 'course_schedules' && row['data'] is! List) ||
            (['course_curricula', 'course_contents'].contains(table) &&
                row['data'] is! Map &&
                row['data'] is! List) ||
            (table == 'course_schedules' && !_semester(row['semester']))) {
          throw const FormatException('Documento do lote acadêmico inválido.');
        }
      } else {
        final filters = asMap(change['filters']);
        final allowed = {idKey, if (table == 'course_schedules') 'semester'};
        if (filters[idKey] != courseId ||
            filters.keys.any((key) => !allowed.contains(key)) ||
            (filters.containsKey('semester') &&
                !_semester(filters['semester']))) {
          throw const FormatException('Exclusão fora do curso do lote.');
        }
      }
    }
  }
  static const tables = [
    'courses',
    'course_curricula',
    'course_contents',
    'course_schedules',
  ];
  final String courseId;
  final List<JsonMap> changes;
  static bool _semester(Object? value) =>
      value is String && RegExp(r'^\d{4}\.[12]$').hasMatch(value);

  void apply(Map<String, List<JsonMap>> documents) {
    for (final change in changes) {
      final table = change['table'] as String;
      final rows = documents[table]!;
      if (change['action'] == 'delete') {
        final filters = asMap(change['filters']);
        final before = rows.length;
        rows.removeWhere(
          (row) => filters.entries.every((e) => textOf(row[e.key]) == e.value),
        );
        if (table == 'courses') {
          if (rows.length == before) {
            throw const FormatException('Curso não encontrado.');
          }
          for (final child in tables.skip(1)) {
            documents[child]!.removeWhere(
              (row) => row['course_id'] == courseId,
            );
          }
        }
        continue;
      }
      var row = asMap(change['row']);
      final keys = table == 'courses'
          ? ['id']
          : table == 'course_schedules'
          ? ['course_id', 'semester']
          : ['course_id'];
      final index = rows.indexWhere(
        (old) => keys.every((key) => old[key] == row[key]),
      );
      if (table == 'courses') {
        if (index < 0 && change['require_existing'] == true) {
          throw const FormatException('Curso não encontrado.');
        }
        final previous = index < 0
            ? <String, dynamic>{}
            : asMap(rows[index]['data']);
        final patch = asMap(row['data']);
        row = {
          ...row,
          'data': {
            ...previous,
            ...patch,
            'id': courseId,
            for (final field in ['semesters', 'profiles'])
              if (previous.containsKey(field) || patch.containsKey(field))
                field: {
                  ...asList(previous[field]),
                  ...asList(patch[field]),
                }.toList(),
          },
        };
      }
      if (index < 0) {
        rows.add(row);
      } else {
        rows[index] = row;
      }
    }
    final index = documents['courses']!.indexWhere(
      (row) => row['id'] == courseId,
    );
    if (index < 0) {
      if (tables
          .skip(1)
          .any(
            (table) =>
                documents[table]!.any((row) => row['course_id'] == courseId),
          )) {
        throw const FormatException(
          'Os documentos precisam de um curso existente.',
        );
      }
      return;
    }
    final row = documents['courses']![index];
    final data = asMap(row['data']);
    final semesters = <String>{
      ...asList(data['semesters']).map(textOf),
      ...documents['course_schedules']!
          .where((row) => row['course_id'] == courseId)
          .map((row) => textOf(row['semester'])),
    }.toList()..sort();
    documents['courses']![index] = {
      ...row,
      'data': {
        ...data,
        'hasCurriculum': documents['course_curricula']!.any(
          (row) => row['course_id'] == courseId,
        ),
        'hasSchedule': documents['course_schedules']!.any(
          (row) => row['course_id'] == courseId,
        ),
        'semesters': semesters,
      },
    };
  }
}
