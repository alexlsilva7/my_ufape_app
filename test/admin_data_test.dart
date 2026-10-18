import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_ufape/features/admin/admin_data.dart';

void main() {
  for (final course in ['bcc', 'eal']) {
    test('$course curriculum keeps records and references after roundtrip', () {
      final asset = object(
        jsonDecode(File('assets/data/$course.json').readAsStringSync()),
      );
      final original = object(asset['curriculum']);
      final normalized = normalizeCurriculum(original);
      final roundtrip = normalizeCurriculum(jsonDecode(jsonEncode(normalized)));
      expect(roundtrip, normalized);
      expect(
        records(normalized['subjects']).length,
        greaterThanOrEqualTo(records(original['subjects']).length),
      );
      for (final subject in records(original['subjects'])) {
        expect(
          records(normalized['subjects']).any(
            (row) =>
                row['code'] == subject['code'] &&
                row['name'] == subject['name'] &&
                row['profile'] == subject['profile'] &&
                row['ementa'] == subject['ementa'],
          ),
          isTrue,
          reason: 'Preserve ${subject['name']}',
        );
      }
      expect(
        records(normalized['profiles']).map((profile) => profile['id']),
        records(original['profiles']).map((profile) => profile['id']),
      );
      final ids = records(normalized['subjects'])
          .map((row) => row['id'])
          .toSet();
      for (final node in records(normalized['treeSubjects'])) {
        expect(ids.contains(node['id']), isTrue);
        for (final id in node['prereqs'] as List? ?? []) {
          expect(ids.contains(id), isTrue);
        }
      }
    });
  }
  test(
    'nullable source code/workload are accepted and distinct nodes survive',
    () {
      final value = normalizeCurriculum({
        'subjects': [],
        'treeSubjects': [
          {
            'id': 'a',
            'code': null,
            'name': 'Projeto A',
            'profile': null,
            'hours': null,
            'prereqs': [],
          },
          {
            'id': 'b',
            'code': null,
            'name': 'Projeto B',
            'profile': null,
            'hours': null,
            'prereqs': ['a'],
          },
        ],
      });
      expect(records(value['subjects']).map((row) => row['name']), [
        'Projeto A',
        'Projeto B',
      ]);
      expect(validateAdminData(value, schedule: false), isEmpty);
      expect(records(value['treeSubjects'])[1]['prereqs'], ['a']);
    },
  );
  test('forward catalogue prerequisites resolve after IDs are assigned', () {
    final value = normalizeCurriculum({
      'subjects': [
        {
          'code': 'B',
          'name': 'Segundo',
          'profile': null,
          'workload': {'total': null},
          'prerequisites': [
            {'code': 'A'},
          ],
        },
        {
          'code': 'A',
          'name': 'Primeiro',
          'profile': null,
          'workload': {'total': null},
          'prerequisites': [],
        },
      ],
    });
    expect(records(value['treeSubjects']).first['prereqs'], [
      records(value['subjects'])[1]['id'],
    ]);
  });
  test('unknown prerequisite evidence remains null', () {
    final value = normalizeCurriculum({
      'treeSubjects': [
        {'id': 'a', 'name': 'Projeto', 'hours': null, 'prereqs': null},
      ],
    });
    expect(records(value['subjects']).single['prerequisites'], isNull);
    expect(records(value['treeSubjects']).single['prereqs'], isNull);
    expect(normalizeCurriculum(value), value);
  });
  test('malformed time and prerequisite cycles block publishing', () {
    expect(
      validateAdminData([
        {
          'id': 'x',
          'name': 'Turma',
          'sessions': [
            {'day': 7, 'time': '29:99 - 03:00'},
          ],
        },
      ], schedule: true),
      isNotEmpty,
    );
    expect(
      validateAdminData({
        'subjects': [],
        'treeSubjects': [
          {
            'id': 'a',
            'name': 'A',
            'prereqs': ['b'],
          },
          {
            'id': 'b',
            'name': 'B',
            'prereqs': ['a'],
          },
        ],
      }, schedule: false).any((error) => error.contains('ciclo')),
      isTrue,
    );
  });
  test('diff preview includes removals', () {
    final diff = changesBetween(
      [
        {'id': 'a'},
        {'id': 'b'},
      ],
      [
        {'id': 'a'},
      ],
    );
    expect(diff.any((line) => line.contains('2 → 1')), isTrue);
    expect(
      diff.any((line) => line.contains(r'$[1]') && line.contains('null')),
      isTrue,
    );
  });
}
