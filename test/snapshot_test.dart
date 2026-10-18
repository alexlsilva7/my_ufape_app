import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:my_ufape/core/api_client.dart';
import 'package:my_ufape/core/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> snapshotState({Map<String, Object> saved = const {}}) async {
  SharedPreferences.setMockInitialValues(saved);
  final api = AcademicApi(
    client: MockClient((_) async => throw Exception('offline test')),
  );
  // No injected asset loader: these tests exercise the real Flutter bundle.
  final state = AppState(api: api);
  await state.initialize();
  return state;
}

Future<void> openCourse(AppState state, String id) async =>
    state.selectCourse(state.courses.firstWhere((course) => course.id == id));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all bundled snapshots load their real catalogues and matrices offline',
    () async {
      final state = await snapshotState();
      expect(state.courses.length, 9);
      const expectations = {
        'bcc': (99, 43, 3200.0),
        'eal': (102, 102, 3900.0),
        'adm': (16, 16, 0.0),
        'medicina-veterinaria': (145, 79, 4150.0),
        'licenciatura-em-letras-portugues-ingles': (47, 47, 3960.0),
      };
      for (final entry in expectations.entries) {
        await openCourse(state, entry.key);
        expect(state.error, isNull, reason: entry.key);
        expect(state.offline, isTrue);
        expect(state.profiles, isNotEmpty);
        expect(
          state.catalogSubjects.length,
          entry.value.$1,
          reason: '${entry.key} official catalogue',
        );
        expect(
          state.subjects.length,
          entry.value.$2,
          reason: '${entry.key} matrix nodes',
        );
        expect(state.activeProfile!.totalHours, entry.value.$3);
        expect(
          state.subjects.fold<double>(0, (sum, subject) => sum + subject.hours),
          greaterThan(0),
        );
        expect(
          state.subjects.every((s) => s.id.isNotEmpty && s.name.isNotEmpty),
          isTrue,
        );
        expect(
          state.subjects.map((s) => s.id).toSet().length,
          state.subjects.length,
        );
        if (state.selectedCourse!.hasSchedule) {
          expect(state.offerings, isNotEmpty, reason: entry.key);
        }
      }
      state.dispose();
    },
  );

  test('BCC graph categories remain separate from official catalogue and contents are joined', () async {
    final state = await snapshotState();
    await openCourse(state, 'bcc');
    expect(state.activeProfile!.id, 'BCC03');
    expect(state.subjects.any((s) => s.type == 'basico'), isTrue);
    expect(
      state.catalogSubjects.any((s) => normalized(s.type).contains('obrigat')),
      isTrue,
    );
    expect(
      state.catalogSubjects.any((s) => s.raw['conteudo_programatico'] != null),
      isTrue,
    );
    final geometry = state.catalogSubjects.firstWhere(
      (s) => s.code == 'MATM3021',
    );
    expect(geometry.raw['conteudo_programatico'], contains('Vetores'));
    final linear = state.subjects.firstWhere((s) => s.id == 'alg_lin');
    expect(linear.prereqs, ['geo_anal']);
    expect(state.isUnlocked(linear), isFalse);
    state.setCompleted(
      state.subjects.firstWhere((s) => s.id == 'geo_anal'),
      true,
    );
    expect(state.isUnlocked(linear), isTrue);
    state.dispose();
  });

  test('bare-list ADM and Letras tree profiles resolve references to matrix node IDs', () async {
    final state = await snapshotState();
    await openCourse(state, 'adm');
    final finance = state.subjects.firstWhere((s) => s.code == 'ADM00007');
    final math = state.subjects.firstWhere((s) => s.code == 'ADM00003');
    expect(finance.prereqs, [math.id]);
    expect(state.missingPrerequisites(finance).map((s) => s.id), [math.id]);
    state.setCompleted(math, true);
    expect(state.isUnlocked(finance), isTrue);
    await openCourse(state, 'licenciatura-em-letras-portugues-ingles');
    final raw = jsonDecode(
      await rootBundle.loadString(
        'assets/data/licenciatura-em-letras-portugues-ingles.json',
      ),
    ) as Map;
    final graph = (raw['curriculum']['treeSubjects'] as List).first as Map;
    expect(state.subjects.first.type, graph['type']);
    expect(state.catalogSubjects.first.type, 'Obrigatória');
    expect(state.activeProfile!.acexHours, 360);
    expect(state.activeProfile!.accHours, 150);
    final english = state.subjects.firstWhere((s) => s.code == 'LET00010');
    expect(english.prereqs, ['no_0001']);
    expect(state.isUnlocked(english), isFalse);
    state.setCompleted(
      state.subjects.firstWhere((s) => s.id == 'no_0001'),
      true,
    );
    expect(state.isUnlocked(english), isTrue);
    state.dispose();
  });

  test('selected and legacy profiles restore; no-code completions remain profile scoped', () async {
    final state = await snapshotState(
      saved: {'selectedCourse': 'bcc', 'selected_profile_bcc': 'BCC02'},
    );
    expect(state.selectedProfile, 'BCC02');
    expect(state.activeProfile!.id, 'BCC02');
    final noCode = state.subjects.firstWhere((s) => s.id == 'old_calc_1');
    expect(noCode.code, isNull);
    state.setCompleted(noCode, true);
    state.setGrade(noCode, '8.5');
    state.setHours(acex: 22);
    expect(state.completedDisciplines, contains('id:BCC02:old_calc_1'));
    await state.selectProfile('BCC03');
    expect(state.subjects.where((s) => state.isCompleted(s)), isEmpty);
    expect(state.acexHours, 0);
    await openCourse(state, 'eal');
    await openCourse(state, 'bcc');
    expect(state.activeProfile!.id, 'BCC03');
    await state.selectProfile('BCC02');
    expect(
      state.isCompleted(state.subjects.firstWhere((s) => s.id == noCode.id)),
      isTrue,
    );
    expect(state.grade(noCode), '8.5');
    expect(state.acexHours, 22);
    await state.selectProfile('made-up-profile');
    expect(state.selectedProfile, 'all');
    state.dispose();
    final legacy = await snapshotState(
      saved: {'selectedCourse': 'bcc', 'bcc_matrix_version': 'antiga'},
    );
    expect(legacy.activeProfile!.id, 'BCC02');
    legacy.dispose();
  });

  test('real EAL graduation progress caps ACE and ACC and counts only completed academics', () async {
    final state = await snapshotState();
    await openCourse(state, 'eal');
    expect(state.selectedSemester, '2026.2');
    expect(state.activeProfile!.id, 'EAL03');
    expect(state.activeProfile!.mandatoryHours, 3210);
    expect(state.activeProfile!.optativeHours, 180);
    final mandatory = state.subjects.firstWhere(
      (s) => !s.isElective && s.hours > 0,
    );
    state.setCompleted(mandatory, true);
    state.setHours(acex: 500, acc: 200);
    expect(state.progress.acexHours, 390);
    expect(state.progress.accHours, 120);
    expect(state.progress.mandatoryHours, mandatory.hours);
    expect(state.progress.doneHours, mandatory.hours + 510);
    expect(
      state.progress.percentage,
      closeTo((mandatory.hours + 510) / 3900 * 100, .0001),
    );
    state.dispose();
  });
}
