import 'package:flutter_test/flutter_test.dart';
import 'package:my_ufape/core/models.dart';

import 'core_test.dart' as fixtures;
import 'test_state.dart';

void main() {
  test(
    'catalog does not rebuild when grades, completions or schedule change',
    () async {
      final state = await fixtures.createState();
      addTearDown(state.dispose);
      var notifications = 0;
      state.catalog.addListener(() => notifications++);
      state.matrix.setGrade(state.matrix.subjects.first, '8');
      state.timetable.toggleDiscipline(state.offerings.first);
      state.timetable.setCompleted(state.offerings.first, true);
      expect(notifications, 0);
      await state.catalog.selectProfile('P2');
      expect(notifications, 1);
      await state.storage.flush();
    },
  );

  test('catalog filters combine search, period, type and profile while retaining electives', () {
    final state = createAppState();
    addTearDown(state.dispose);
    Subject subject(String id, String profile, Object period, String type) =>
        Subject.fromJson({
          'id': id,
          'name': 'Cálculo $id',
          'code': id,
          'period': period,
          'type': type,
        }, profile: profile);
    state.context.catalogSubjects = [
      subject('one', 'P1', 1, 'obrigatoria'),
      subject('two', 'P2', 2, 'obrigatoria'),
      subject('elective', 'Optativa', '0', 'obrigatoria'),
    ];
    state.selectedProfile = 'P1';
    final vm = state.catalog;
    expect(vm.profiles, ['P1', 'P2']);
    expect(vm.profiles, same(vm.profiles));
    expect(vm.filteredSubjects().map((s) => s.id), ['one', 'elective']);
    expect(vm.filteredSubjects(query: 'CALCULO', period: 1).single.id, 'one');
    expect(vm.filteredSubjects(type: 'optativa').single.id, 'elective');
    expect(vm.filteredSubjects(type: 'obrigatoria').single.id, 'one');
    state.selectedProfile = 'all';
    expect(vm.filteredSubjects(), hasLength(3));
    expect(vm.filteredSubjects(query: 'two', period: 1), isEmpty);
    state.context.catalogSubjects = [subject('single', 'P1', 1, 'obrigatoria')];
    state.selectedProfile = 'P2';
    expect(vm.filteredSubjects().single.id, 'single');
    state.context.catalogSubjects[0] = subject(
      'replacement',
      'P3',
      3,
      'obrigatoria',
    );
    expect(vm.profiles, ['P3']);
    expect(vm.periods, [3]);
    expect(vm.filteredSubjects(query: 'single'), isEmpty);
    expect(vm.filteredSubjects(query: 'replacement').single.id, 'replacement');
  });
}
