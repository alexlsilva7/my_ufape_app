import 'dart:convert';

typedef Json = Map<String, dynamic>;

Json object(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<Json> records(dynamic value) =>
    value is List ? value.map(object).toList() : [];
dynamic cloneJson(dynamic value) => jsonDecode(jsonEncode(value));
String prettyJson(dynamic value) =>
    const JsonEncoder.withIndent('  ').convert(value);

/// Preserve the complete academic schema while keeping catalogue and graph in sync.
Json normalizeCurriculum(dynamic input) {
  final data = input is List
      ? <String, dynamic>{'subjects': input}
      : object(cloneJson(input));
  final profiles = records(data['profiles']);
  var nodes = records(data['treeSubjects']);
  if (nodes.isEmpty) {
    nodes = profiles
        .expand(
          (profile) => records(profile['subjects']).map(
            (node) => {...node, 'profile': node['profile'] ?? profile['id']},
          ),
        )
        .toList();
  }
  var subjects = records(data['subjects']);
  // Extraction responses use `subjects` for both catalogue and graph rows.
  if (nodes.isEmpty &&
      subjects.any(
        (row) => row.containsKey('prereqs') || row.containsKey('hours'),
      )) {
    nodes = records(cloneJson(subjects));
    subjects = [];
  }
  for (final node in nodes) {
    if (!subjects.any(
      (subject) =>
          (subject['id'] != null &&
              node['id'] != null &&
              subject['id'] == node['id']) ||
          (subject['id'] == null &&
              subject['code'] != null &&
              subject['code'] == node['code'] &&
              subject['profile'] == node['profile']),
    )) {
      subjects.add({
        'id': node['id'],
        'code': node['code'],
        'name': node['name'],
        'profile': node['profile'],
        'period': node['period'],
        'type': node['academicType'],
        'credits': node['credits'],
        'workload':
            node['workload'] ??
            {
              'teorica': null,
              'pratica': null,
              'extensao': null,
              'total': node['hours'],
            },
        'ementa': node['desc'],
        'prerequisites': (node['prereqs'] as List?)?.map((id) {
          final targets = nodes.where((target) => target['id'] == id);
          return {
            'id': id,
            'code': targets.firstOrNull?['code'],
            'name': targets.firstOrNull?['name'],
          };
        }).toList(),
      });
    }
  }
  final used = <String>{};
  final nextNodes = <Json>[];
  for (var index = 0; index < subjects.length; index++) {
    final subject = subjects[index];
    final matches = nodes.where(
      (node) => subject['id'] != null
          ? node['id'] == subject['id']
          : subject['code'] != null &&
                subject['code'] == node['code'] &&
                subject['profile'] == node['profile'],
    );
    if (matches.length > 1) {
      throw FormatException('Correspondência ambígua: ${subject['code']}.');
    }
    final old = matches.firstOrNull ?? <String, dynamic>{};
    final id =
        '${subject['id'] ?? old['id'] ?? 'subject_${Uri.encodeComponent('${subject['profile'] ?? 'default'}')}_${Uri.encodeComponent('${subject['code'] ?? index}')}'}';
    if (!used.add(id)) throw FormatException('Identificador duplicado: $id.');
    subject['id'] = id;
    nextNodes.add({
      ...old,
      'id': id,
      'code': subject['code'],
      'name': subject['name'],
      'profile': subject['profile'],
      'period': subject['period'] == 'Optativa'
          ? 0
          : num.tryParse('${subject['period']}'),
      'hours': object(subject['workload'])['total'],
      'workload': subject['workload'],
      'credits': subject['credits'],
      'academicType': subject['type'],
      'desc': subject['ementa'],
      'type': old['type'] ?? 'outros',
      'corequisites': subject['corequisites'],
      'equivalences': subject['equivalences'],
      'evidence': subject['evidence'],
      'prereqs':
          old['prereqs'] ??
          records(subject['prerequisites'])
              .map(
                (ref) =>
                    ref['id'] ??
                    subjects
                        .where(
                          (candidate) =>
                              candidate['profile'] == subject['profile'] &&
                              candidate['code'] == ref['code'],
                        )
                        .firstOrNull?['id'],
              )
              .whereType<String>()
              .toList(),
    });
  }
  for (var index = 0; index < nextNodes.length; index++) {
    final node = nextNodes[index];
    final old = nodes
        .where((candidate) => candidate['id'] == node['id'])
        .firstOrNull;
    if (old?['prereqs'] == null) {
      node['prereqs'] = subjects[index]['prerequisites'] == null
          ? null
          : records(subjects[index]['prerequisites']).expand((ref) {
              if (ref['id'] != null) return [ref['id']];
              final matches = subjects.where(
                (candidate) =>
                    candidate['profile'] == subjects[index]['profile'] &&
                    ref['code'] != null &&
                    candidate['code'] == ref['code'],
              );
              return matches.length == 1 ? [matches.first['id']] : <dynamic>[];
            }).toList();
    }
    node['prereqs'] = (node['prereqs'] as List?)?.where(used.contains).toList();
  }
  data['subjects'] = subjects;
  data['treeSubjects'] = nextNodes;
  data['profiles'] = profiles
      .map(
        (profile) => {
          ...profile,
          'subjects': nextNodes
              .where((node) => node['profile'] == profile['id'])
              .toList(),
        },
      )
      .toList();
  if (data['_extraction'] != null) data['extraction'] = data['_extraction'];
  return data;
}

List<String> validateAdminData(dynamic input, {required bool schedule}) {
  final errors = <String>[];
  final data = schedule ? records(input) : records(object(input)['subjects']);
  final ids = <String>{};
  final courseNames = data
      .map((row) => row['courseName'])
      .whereType<String>()
      .where((value) => value.isNotEmpty)
      .toSet();
  if (courseNames.length > 1) {
    errors.add(
      'Há cursos diferentes na importação; separe os documentos antes de salvar.',
    );
  }
  if (schedule &&
      data
              .map((row) => row['semester'])
              .whereType<String>()
              .where((value) => value.isNotEmpty)
              .toSet()
              .length >
          1) {
    errors.add('Há semestres diferentes na importação.');
  }
  for (var i = 0; i < data.length; i++) {
    final row = data[i];
    final label = '${row['name'] ?? '#${i + 1}'}';
    if ('${row['name'] ?? ''}'.trim().isEmpty) {
      errors.add('Registro ${i + 1}: nome obrigatório.');
    }
    if (row['id'] != null && !ids.add('${row['id']}')) {
      errors.add('$label: identificador repetido.');
    }
    final period = row['period'];
    if (period != null &&
        ![
          'optativa',
          'optativo',
          'eletiva',
          'eletivo',
        ].contains('$period'.toLowerCase()) &&
        (!RegExp(r'^\d+$').hasMatch('$period') ||
            (num.tryParse('$period') ?? -1) < 0)) {
      errors.add('$label: período inválido.');
    }
    if (schedule) {
      if (row['id'] == null || '${row['id']}'.isEmpty) {
        errors.add('$label: identificador obrigatório.');
      }
      final sessions = records(row['sessions']);
      if (sessions.isEmpty) {
        errors.add('$label: cadastre ao menos um encontro.');
      }
      for (final session in sessions) {
        final day = int.tryParse('${session['day']}') ?? 0;
        if (session['day'] is! int || day < 1 || day > 6) {
          errors.add('$label: dia deve estar entre 1 e 6.');
        }
        final match = RegExp(r'^(\d{2}):(\d{2}) - (\d{2}):(\d{2})$')
            .firstMatch('${session['time']}');
        if (match == null) {
          errors.add('$label: horário inválido.');
        } else {
          final parts = List.generate(4, (i) => int.parse(match.group(i + 1)!));
          if (parts[0] > 23 ||
              parts[2] > 23 ||
              parts[1] > 59 ||
              parts[3] > 59 ||
              parts[0] * 60 + parts[1] >= parts[2] * 60 + parts[3]) {
            errors.add(
              '$label: horário inválido ou término anterior ao início.',
            );
          }
        }
      }
    } else {
      final type = row['type'];
      if (type != null &&
          !RegExp(
            r'^(obrigatóri[ao]|obrigatori[ao]|optativ[ao]|eletiv[ao])$',
            caseSensitive: false,
          ).hasMatch('$type')) {
        errors.add('$label: tipo acadêmico inválido.');
      }
      for (final entry in {
        ...object(row['workload']),
        'credits': row['credits'],
      }.entries) {
        if (entry.value != null &&
            (entry.value is! num || entry.value < 0 || entry.value % 1 != 0)) {
          errors.add('$label: ${entry.key} deve ser inteiro não negativo.');
        }
      }
      for (final ref in records(row['prerequisites'])) {
        if ((ref['code'] != null &&
                row['code'] != null &&
                '${ref['code']}'.toLowerCase() ==
                    '${row['code']}'.toLowerCase()) ||
            (ref['code'] == null &&
                ref['name'] != null &&
                '${ref['name']}'.toLowerCase() ==
                    '${row['name']}'.toLowerCase())) {
          errors.add(
            '$label: disciplina aparece como pré-requisito dela mesma.',
          );
        }
      }
    }
  }
  if (!schedule) {
    final nodes = records(object(input)['treeSubjects']);
    final byId = {for (final node in nodes) '${node['id']}': node};
    final visiting = <String>{}, visited = <String>{};
    void visit(Json node) {
      final id = '${node['id']}';
      if (visiting.contains(id)) {
        errors.add('${node['name']}: ciclo no grafo de pré-requisitos.');
        return;
      }
      if (visited.contains(id)) return;
      visiting.add(id);
      for (final ref in node['prereqs'] as List? ?? []) {
        if (!byId.containsKey('$ref')) {
          errors.add('${node['name']}: pré-requisito inexistente $ref.');
        } else {
          visit(byId['$ref']!);
        }
      }
      visiting.remove(id);
      visited.add(id);
    }

    for (final node in nodes) {
      visit(node);
    }
  }
  return errors;
}

List<String> changesBetween(
  dynamic before,
  dynamic after, [
  String path = r'$',
]) {
  if (jsonEncode(before) == jsonEncode(after)) return [];
  if (before is Map && after is Map) {
    return {...before.keys, ...after.keys}
        .expand((key) => changesBetween(before[key], after[key], '$path.$key'))
        .toList();
  }
  if (before is List && after is List) {
    final result = <String>[
      '$path: ${before.length} → ${after.length} registros',
    ];
    for (
      var i = 0;
      i < (before.length > after.length ? before.length : after.length);
      i++
    ) {
      result.addAll(
        changesBetween(
          i < before.length ? before[i] : null,
          i < after.length ? after[i] : null,
          '$path[$i]',
        ),
      );
    }
    return result;
  }
  String short(dynamic value) {
    final text = jsonEncode(value);
    return text.length > 140 ? '${text.substring(0, 140)}…' : text;
  }

  return ['$path: ${short(before)} → ${short(after)}'];
}
