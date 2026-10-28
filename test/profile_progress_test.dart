import 'dart:convert';

import 'test_state.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:my_ufape/core/api_client.dart';
import 'package:my_ufape/core/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> openBcc() async {
  SharedPreferences.setMockInitialValues({});
  final state = createAppState(
    api: AcademicApi(
      client: MockClient((_) async => throw Exception('offline')),
    ),
  );
  await state.initialize();
  await openCourse(state, 'bcc');
  await state.selectProfile('BCC03');
  return state;
}

Future<void> openCourse(AppState state, String id) async =>
    state.selectCourse(state.courses.firstWhere((c) => c.id == id));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('profile export roundtrips completion, normalized grades, selections and hours', () async {
    final state = await openBcc();
    final first = state.subjects.first;
    state.setCompleted(first, true);
    state.setGrade(first, '9,5');
    state.setHours(acex: 35, acc: 12);
    state.addElective(name: 'Optativa pessoal', hours: 45);
    state.setCompleted(state.subjects.last, true);
    final exported = state.exportProfileProgress();
    final json = jsonDecode(exported) as Map;
    expect(json['course'], 'bcc');
    expect(json['profileId'], 'BCC03');
    expect(json['statuses'][first.id], 'concluido');
    state.resetProfileProgress();
    expect(state.progress.doneHours, 0);
    expect(state.subjects.any((s) => s.additionalElective), isFalse);
    expect(await state.importProfileProgress(exported), isTrue);
    expect(state.isCompleted(first), isTrue);
    expect(state.grade(first), '9.5');
    expect(state.subjects.last.displayName, 'Optativa pessoal');
    expect(state.isCompleted(state.subjects.last), isTrue);
    expect(state.acexHours, 35);
    expect(state.accHours, 12);
    final legacy = Map<String, dynamic>.from(json)..remove('statuses');
    expect(await state.importProfileProgress(jsonEncode(legacy)), isTrue);
    state.dispose();
  });
  test('wrong course/profile and malformed fields reject atomically', () async {
    final state = await openBcc();
    state.setCompleted(state.subjects.first, true);
    state.setHours(acex: 10);
    final before = state.exportProfileProgress();
    for (final patch in <Map<String, dynamic>>[
      {'course': 'eal'},
      {'profileId': 'BCC02'},
      {'subjects': 'invalid'},
      {
        'subjects': [
          {'id': 12},
        ],
      },
      {
        'subjects': [
          {'id': state.subjects.first.id, 'grade': '11'},
        ],
      },
      {
        'subjects': [
          {'id': state.subjects.first.id, 'status': 'unknown'},
        ],
      },
      {'acexHours': -1},
      {'accHours': '20'},
      {
        'statuses': {'x': 'bad'},
      },
    ]) {
      expect(
        await state.importProfileProgress(
          jsonEncode({...jsonDecode(before) as Map, ...patch}),
        ),
        isFalse,
        reason: '$patch',
      );
      expect(state.exportProfileProgress(), before);
    }
    state.dispose();
  });
  test(
    'imports retain official metadata and sanitize/deduplicate added electives',
    () async {
      final state = await openBcc();
      final first = state.subjects.first;
      final slot = state.subjects.firstWhere((s) => s.isGenericElective);
      final otherSlot = state.subjects.lastWhere((s) => s.isGenericElective);
      final imported =
          jsonDecode(state.exportProfileProgress()) as Map<String, dynamic>;
      imported['subjects'] = [
        {
          ...first.toJson(),
          'name': 'Injected',
          'hours': 99999,
          'type': 'optativa',
          'prereqs': ['evil'],
          'status': 'concluido',
          'grade': '8,5',
        },
        {
          ...slot.toJson(),
          'electiveSelection': {
            'source': 'catalog',
            'name': 'Catálogo',
            'hours': 60,
            'code': 'OPT900',
          },
          'status': 'concluido',
        },
        {
          ...otherSlot.toJson(),
          'electiveSelection': {
            'source': 'catalog',
            'name': 'Duplicada',
            'hours': 60,
            'code': 'OPT900',
          },
        },
        {
          'id': 'personal_opt_valid',
          'additionalElective': true,
          'name': 'Injected',
          'type': 'computacao',
          'period': -7,
          'hours': 90000,
          'prereqs': ['evil'],
          'status': 'concluido',
          'electiveSelection': {
            'source': 'manual',
            'name': 'Manual',
            'hours': 30,
          },
        },
        {
          'id': 'personal_opt_duplicate',
          'additionalElective': true,
          'electiveSelection': {
            'source': 'catalog',
            'name': 'Duplicada',
            'hours': 60,
            'code': 'OPT900',
          },
        },
        {
          'id': 'personal_opt_invalid',
          'additionalElective': true,
          'electiveSelection': {
            'source': 'manual',
            'name': 'Inválida',
            'hours': -4,
          },
        },
        {
          'id': 'unsafe_id',
          'additionalElective': true,
          'electiveSelection': {
            'source': 'manual',
            'name': 'Inválida',
            'hours': 30,
          },
        },
      ];
      expect(await state.importProfileProgress(jsonEncode(imported)), isTrue);
      final restored = state.subjects.first;
      expect(restored.name, first.name);
      expect(restored.hours, first.hours);
      expect(restored.type, first.type);
      expect(restored.prereqs, first.prereqs);
      expect(state.grade(first), '8.5');
      final extras = state.subjects.where((s) => s.additionalElective).toList();
      expect(extras.length, 1);
      expect(extras.single.name, 'Optativa adicional');
      expect(extras.single.type, 'optativa');
      expect(extras.single.hours, 0);
      expect(extras.single.prereqs, isEmpty);
      expect(extras.single.period, 9);
      expect(extras.single.displayName, 'Manual');
      expect(extras.single.displayHours, 30);
      expect(
        state.subjects
            .where((s) => s.electiveSelection?.code == 'OPT900')
            .length,
        1,
      );
      state.dispose();
    },
  );
  test('reset removes current profile identities and additions, preserves other profile/course and schedule', () async {
    final state = await openBcc();
    state.setCompleted(state.subjects.first, true);
    state.setGrade(state.subjects.first, '9');
    state.setHours(acex: 90, acc: 45);
    final slot = state.subjects.firstWhere((s) => s.isGenericElective);
    state.setElective(
      slot,
      name: 'Catálogo pessoal',
      hours: 60,
      code: 'OPT_RESET',
    );
    state.setCompleted(state.subjects.firstWhere((s) => s.id == slot.id), true);
    state.addElective(name: 'Extra', hours: 30);
    state.setCompleted(state.subjects.last, true);
    await state.selectProfile('BCC02');
    final other = state.subjects.firstWhere((s) => s.id == 'old_calc_1');
    state.setCompleted(other, true);
    await openCourse(state, 'eal');
    final eal = state.subjects.first;
    state.setCompleted(eal, true);
    await openCourse(state, 'bcc');
    await state.selectProfile('BCC03');
    final offer = state.offerings.firstWhere((d) => d.code == 'MATM3021');
    state.toggleDiscipline(offer);
    final scheduled = state.subjects.firstWhere((s) => s.code == offer.code);
    state.resetProfileProgress();
    expect(state.completedDisciplines, {'id:BCC02:old_calc_1'});
    expect(
      state.subjects.any(
        (s) => s.additionalElective || s.electiveSelection != null,
      ),
      isFalse,
    );
    expect(state.subjects.every((s) => state.grade(s).isEmpty), isTrue);
    expect(state.acexHours, 0);
    expect(state.accHours, 0);
    expect(state.schedule.map((d) => d.id), contains(offer.id));
    expect(state.subjectStatus(scheduled), 'cursando');
    await openCourse(state, 'eal');
    expect(state.isCompleted(eal), isTrue);
    await openCourse(state, 'bcc');
    await state.selectProfile('BCC02');
    expect(state.isCompleted(other), isTrue);
    state.dispose();
  });
  test(
    'grade boundary accepts comma or point only within zero to ten',
    () async {
      final state = await openBcc();
      final subject = state.subjects.first;
      state.setGrade(subject, '9,25');
      expect(state.grade(subject), '9.25');
      for (final invalid in ['-1', '10.1', 'NaN', 'Infinity', 'abc']) {
        state.setGrade(subject, invalid);
        expect(state.grade(subject), '9.25');
      }
      state.setGrade(subject, '0');
      expect(state.grade(subject), '0');
      state.setGrade(subject, '10');
      expect(state.grade(subject), '10');
      state.setGrade(subject, '');
      expect(state.grade(subject), '');
      state.dispose();
    },
  );
}
