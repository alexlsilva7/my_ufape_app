import 'package:flutter_test/flutter_test.dart';
import 'package:my_ufape/core/models.dart';

import 'test_state.dart';
import 'core_test.dart' as fixtures;

Discipline offering(
  String id, {
  String name = 'Cálculo',
  String? profile = 'P1',
  int? period = 1,
}) => Discipline(
  id: id,
  name: name,
  profile: profile,
  period: period,
  professor: 'José',
  code: 'MAT01',
  sessions: [],
);

void main() {
  test('semester restoration publishes only the reconciled plan', () async {
    final state = await fixtures.createState();
    addTearDown(state.dispose);
    final vm = state.timetable;
    vm.toggleDiscipline(state.offerings.first);
    var notifications = 0;
    vm.addListener(() {
      notifications++;
      expect(vm.selectedSemester, '2099.1');
      expect(vm.plan.semester, '2099.1');
      expect(vm.schedule, isEmpty);
    });
    state.context.selectedSemester = '2099.1';
    state.context.notifyListeners();
    expect(notifications, 1);
    await state.storage.flush();
  });

  test(
    'profile change publishes a single synchronous schedule update',
    () async {
      final state = await fixtures.createState();
      addTearDown(state.dispose);
      var notifications = 0;
      state.timetable.addListener(() {
        notifications++;
        expect(state.timetable.selectedProfile, 'P2');
      });
      await state.timetable.selectProfile('P2');
      expect(notifications, 1);
      await state.storage.flush();
    },
  );

  test(
    'completion publishes once after removing the completed offering',
    () async {
      final state = await fixtures.createState();
      addTearDown(state.dispose);
      final vm = state.timetable;
      final selected = state.offerings.first;
      vm.toggleDiscipline(selected);
      var notifications = 0;
      vm.addListener(() {
        notifications++;
        expect(vm.schedule, isEmpty);
        expect(vm.isCompleted(selected), isTrue);
      });
      await state.completions.setCompleted(
        state.context.courseId,
        selected,
        true,
      );
      expect(notifications, 1);
      await state.storage.flush();
    },
  );

  test('direct plan edits still notify immediately', () async {
    final state = await fixtures.createState();
    addTearDown(state.dispose);
    final vm = state.timetable;
    var notifications = 0;
    vm.addListener(() => notifications++);
    vm.toggleDiscipline(state.offerings.first);
    expect(notifications, 1);
    expect(vm.schedule, hasLength(1));
    final clearing = vm.clearSchedule();
    expect(notifications, 2);
    expect(vm.schedule, isEmpty);
    await clearing;
    await state.storage.flush();
  });

  test(
    'schedule search preserves accents, shared offerings and period precedence',
    () {
      final state = createAppState();
      addTearDown(state.dispose);
      state.offerings = [
        offering('one'),
        offering('two', profile: 'P2', period: 2),
        offering('common', profile: 'Sem perfil', period: 3),
        offering('elective', profile: 'Optativa', period: 0),
      ];
      final vm = state.timetable;
      expect(vm.filteredOfferings(profile: 'P1').map((d) => d.id), [
        'one',
        'common',
        'elective',
      ]);
      expect(
        vm.filteredOfferings(query: 'calculo', profile: 'all', period: 99),
        hasLength(4),
      );
      expect(vm.filteredOfferings(query: 'jose', profile: 'P2'), hasLength(3));
      expect(
        vm.filteredOfferings(query: 'MAT01', profile: 'all'),
        hasLength(4),
      );
      expect(
        vm.filteredOfferings(period: 0, profile: 'P1').single.id,
        'elective',
      );
      expect(vm.offeringPeriods, [1, 2, 3]);
      expect(vm.offeringProfiles, ['P1', 'P2', 'Sem perfil']);
      expect(vm.hasElectives, isTrue);
    },
  );

  test('schedule index reuses results and invalidates on replacement and in-place edits', () {
    final state = createAppState();
    addTearDown(state.dispose);
    state.offerings = [offering('one')];
    final vm = state.timetable;
    final first = vm.filteredOfferings(query: 'cálculo', profile: 'all');
    expect(vm.filteredOfferings(query: 'calculo', profile: 'all'), same(first));
    expect(() => first.clear(), throwsUnsupportedError);
    final profiles = vm.offeringProfiles;
    expect(vm.offeringProfiles, same(profiles));
    state.offerings[0] = offering(
      'replacement',
      name: 'Física',
      profile: 'P2',
      period: 2,
    );
    expect(vm.filteredOfferings(query: 'calculo', profile: 'all'), isEmpty);
    expect(vm.offeringProfiles, ['P2']);
    state.offerings.add(offering('elective', period: 0));
    expect(vm.hasElectives, isTrue);
    expect(vm.filteredOfferings(profile: 'all'), hasLength(2));
    state.offerings = [];
    expect(vm.filteredOfferings(profile: 'all'), isEmpty);
    expect(vm.offeringProfiles, isEmpty);
    expect(vm.offeringPeriods, isEmpty);
    expect(vm.hasElectives, isFalse);
  });
}
