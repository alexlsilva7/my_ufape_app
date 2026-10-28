import 'dart:convert';
import 'dart:async';

import 'test_state.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_ufape/core/api_client.dart';
import 'package:my_ufape/core/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

final courseA = {
  'id': 'a',
  'name': 'Curso A',
  'shortName': 'A',
  'hasSchedule': true,
  'hasCurriculum': true,
  'semesters': ['2026.1', '2026.2'],
};
final courseB = {...courseA, 'id': 'b', 'name': 'Curso B'};
Map<String, dynamic> subject(
  String id, {
  String? code,
  String name = 'Disciplina',
  int period = 1,
  String type = 'computacao',
  List<String> prereqs = const [],
}) => {
  'id': id,
  'code': code,
  'name': name,
  'hours': 60,
  'period': period,
  'type': type,
  'prereqs': prereqs,
};
Map<String, dynamic> offering(String id, String code, String time) => {
  'id': id,
  'code': code,
  'name': 'Oferta $id',
  'period': 1,
  'profile': 'P1',
  'sessions': [
    {'day': 1, 'time': time},
  ],
};
final details = {
  'course': courseA,
  'curriculum': {
    'activeProfileId': 'P1',
    'profiles': [
      {
        'id': 'P1',
        'name': 'Perfil 1',
        'totalHours': 300,
        'acexHours': 30,
        'accHours': 20,
        'subjects': [
          subject('first', code: 'CS1', name: 'Inteligência artificial'),
          subject('second', code: 'CS2', prereqs: ['first']),
          subject('slot', name: 'Optativa I', type: 'optativa'),
        ],
      },
      {
        'id': 'P2',
        'name': 'Perfil 2',
        'subjects': [subject('different-id', code: 'CS1'), subject('no-code')],
      },
    ],
  },
  'schedule': [
    offering('one', 'CS1', '07:30 - 09:30'),
    offering('overlap', 'CS2', '08:30 - 10:30'),
    offering('adjacent', 'CS3', '09:30 - 10:30'),
  ],
  'contents': {
    'subjects': [
      subject(
        'named',
        code: 'OPT1',
        name: 'Inteligência artificial',
        type: 'optativa',
        period: 0,
      ),
    ],
  },
};
Future<AppState> createState({
  Map<String, Object> saved = const {},
  bool fail = false,
}) async {
  SharedPreferences.setMockInitialValues({
    'selectedSemester': '2026.1',
    ...saved,
  });
  final api = AcademicApi(
    client: MockClient((request) async {
      if (fail) throw Exception('offline');
      return http.Response(
        jsonEncode(
          request.url.path == '/api/courses'
              ? {
                  'courses': [courseA, courseB],
                }
              : details,
        ),
        200,
      );
    }),
  );
  final state = createAppState(
    api: api,
    assetLoader: (path) async => jsonEncode(
      path.endsWith('courses.json')
          ? {
              'courses': [courseA, courseB],
            }
          : {
              ...details,
              'schedules': {'2026.1': details['schedule']},
            },
    ),
  );
  await state.initialize();
  await state.selectCourse(state.courses.first);
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'a fresh-install backup is restorable and retains explicit default keys',
    () async {
      SharedPreferences.setMockInitialValues({});
      final state = createAppState(
        api: AcademicApi(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'courses': [courseA],
              }),
              200,
            ),
          ),
        ),
      );
      await state.initialize();
      final exported = state.exportBackup();
      final data = jsonDecode(exported) as Map;
      expect(data.containsKey('themePreference'), isTrue);
      expect(data['themePreference'], isNull);
      expect(data.containsKey('selectedCourse'), isTrue);
      state.cycleTheme();
      expect(await state.importBackup(exported), isTrue);
      expect(state.themeMode.name, 'light');
      expect(state.selectedCourse, isNull);
      state.dispose();
    },
  );
  test(
    'API rejects SPA HTML responses and only sends explicit authentication',
    () async {
      final requests = <http.Request>[];
      final api = AcademicApi(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            request.url.path == '/html' ? '<html>SPA</html>' : '{}',
            200,
          );
        }),
      );
      await api.request('/public');
      await api.request('/admin', token: 'explicit');
      expect(requests.first.headers.containsKey('Authorization'), isFalse);
      expect(requests.last.headers['Authorization'], 'Bearer explicit');
      await expectLater(api.request('/html'), throwsFormatException);
      api.close();
    },
  );
  test('sessions reject partial overlaps but allow adjacent intervals', () {
    final a = Session(day: 1, time: '07:30 - 09:30');
    expect(a.overlaps(Session(day: 1, time: '08:30 – 10:30')), isTrue);
    expect(a.overlaps(Session(day: 1, time: '09:30 - 10:30')), isFalse);
    expect(a.overlaps(Session(day: 2, time: '08:30 - 10:30')), isFalse);
  });
  test('course and semester schedules remain isolated and completion removes selected offers', () async {
    final state = await createState();
    expect(state.toggleDiscipline(state.offerings.first), isNull);
    expect(state.toggleDiscipline(state.offerings[1]), contains('Conflito'));
    expect(state.schedule.length, 1);
    expect(state.toggleDiscipline(state.offerings[2]), isNull);
    await state.selectSemester('2026.2');
    expect(state.schedule, isEmpty);
    await state.selectSemester('2026.1');
    expect(state.schedule.length, 2);
    await state.selectCourse(state.courses.last);
    expect(state.schedule, isEmpty);
    await state.selectCourse(state.courses.first);
    expect(state.schedule.length, 2);
    state.setCompleted(state.subjects.first, true);
    expect(state.schedule.map((s) => s.id), isNot(contains('one')));
    expect(
      state.toggleDiscipline(state.offerings.first),
      contains('concluída'),
    );
    state.dispose();
  });
  test(
    'completion is shared by code while grades and hours stay profile scoped',
    () async {
      final state = await createState();
      await state.selectProfile('P1');
      state.setSubjectStatus(state.subjects.first, 'concluido');
      state.setGrade(state.subjects.first, '9.5');
      state.setHours(acex: 50, acc: 10);
      expect(state.isUnlocked(state.subjects[1]), isTrue);
      expect(state.progress.doneHours, 100);
      await state.selectProfile('P2');
      expect(state.isCompleted(state.subjects.first), isTrue);
      expect(state.grade(state.subjects.first), '');
      expect(state.acexHours, 0);
      await state.selectProfile('P1');
      expect(state.grade(state.subjects.first), '9.5');
      expect(state.acexHours, 50);
      state.dispose();
    },
  );
  test('offline snapshot and accents search work', () async {
    final state = await createState(fail: true);
    expect(state.offline, isTrue);
    expect(state.subjects, isNotEmpty);
    expect(
      state.catalogSubjects.any(
        (s) => normalized(s.name).contains('inteligencia'),
      ),
      isTrue,
    );
    state.dispose();
  });
  test('unknown semesters normalize and stale course responses cannot overwrite selection', () async {
    SharedPreferences.setMockInitialValues({});
    final delayed = Completer<http.Response>();
    final api = AcademicApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/courses') {
          return http.Response(
            jsonEncode({
              'courses': [courseA, courseB],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/a')) return delayed.future;
        return http.Response(
          jsonEncode({...details, 'course': courseB, 'schedule': []}),
          200,
        );
      }),
    );
    final state = createAppState(api: api);
    await state.initialize();
    final pending = state.selectCourse(state.courses.first);
    await state.selectCourse(state.courses.last);
    delayed.complete(http.Response(jsonEncode(details), 200));
    await pending;
    expect(state.selectedCourse!.id, 'b');
    expect(state.offerings, isEmpty);
    await state.selectSemester('garbage');
    expect(state.selectedSemester, '2026.1');
    state.dispose();
  });
  test(
    'backup whitelist rejects malformed values and excludes credentials',
    () async {
      final state = await createState(
        saved: {
          'access_token': 'secret',
          'adminPassword': 'secret',
          'themePreference': 'dark',
        },
      );
      final backup = jsonDecode(state.exportBackup()) as Map;
      expect(backup.containsKey('access_token'), isFalse);
      expect(backup['themePreference'], 'dark');
      expect(await state.importBackup('{"schedule_a_2026.1":42}'), isFalse);
      expect(await state.importBackup('{"access_token":"attacker"}'), isFalse);
      state.dispose();
    },
  );
  test('elective selections persist, validate and cannot double count a catalog discipline', () async {
    final state = await createState();
    final slot = state.subjects.last;
    expect(
      state.setElective(
        slot,
        name: 'Aprendizado de máquina',
        hours: 60,
        code: 'OPT1',
        subjectId: 'named',
      ),
      isNull,
    );
    expect(
      state.addElective(name: 'Duplicada', hours: 60, code: 'OPT1'),
      isNotNull,
    );
    expect(state.addElective(name: 'Inválida', hours: double.nan), isNotNull);
    expect(state.addElective(name: 'Outra optativa', hours: 30), isNull);
    state.setCompleted(state.subjects.last, true);
    expect(state.progress.optativeHours, 30);
    await state.selectProfile('P2');
    await state.selectProfile('P1');
    expect(state.subjects.last.additionalElective, isTrue);
    expect(state.subjects.last.displayName, 'Outra optativa');
    expect(
      state.subjects.firstWhere((s) => s.id == 'slot').displayCode,
      'OPT1',
    );
    state.dispose();
  });
  test(
    'legacy backup completion migrates without pulling stale live completions',
    () async {
      final state = await createState();
      state.setCompleted(state.subjects[1], true);
      final backup = {
        'selectedCourse': 'a',
        'selectedSemester': '2026.1',
        'a_matriz_progress_P1': jsonEncode([
          {'id': 'first', 'status': 'concluido'},
        ]),
      };
      expect(await state.importBackup(jsonEncode(backup)), isTrue);
      expect(state.isCompleted(state.subjects.first), isTrue);
      expect(state.isCompleted(state.subjects[1]), isFalse);
      state.dispose();
    },
  );
}
