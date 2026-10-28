import 'dart:convert';
import 'dart:io';

import 'test_state.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ufape/core/app_state.dart';
import 'package:my_ufape/features/academic/schedule/widgets/offering_card.dart';
import 'package:my_ufape/features/academic/schedule/schedule_view.dart';

void main() {
  for (final scenario in [
    ('desktop', const Size(1440, 1000), 1.0),
    ('phone', const Size(375, 844), 1.0),
    ('large text', const Size(375, 1000), 3.0),
  ]) {
    testWidgets('electives remain last and reachable on ${scenario.$1}', (
      tester,
    ) async {
      tester.view.physicalSize = scenario.$2;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final reference = asMap(
        jsonDecode(
          File('test/fixtures/schedule_bcc_2026_2.json').readAsStringSync(),
        ),
      );
      final state = createAppState()
        ..selectedCourse = CourseMeta.fromJson(asMap(reference['course']))
        ..selectedSemester = '2026.2'
        ..selectedProfile = 'BCC03'
        ..offerings = asList(reference['schedule'])
            .map((item) => Discipline.fromJson(asMap(item)))
            .toList();
      addTearDown(state.dispose);
      final electives = state.filteredOfferings(period: 0);
      expect(electives, hasLength(9));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scenario.$3)),
            child: child!,
          ),
          home: Scaffold(body: ScheduleView(viewModel: state.timetable)),
        ),
      );
      await tester.pumpAndSettle();

      final filter = find.byKey(const ValueKey('schedule-period-0'));
      final lastPeriod = find.byKey(const ValueKey('schedule-period-9'));
      expect(
        tester.getRect(filter).left,
        greaterThan(tester.getRect(lastPeriod).right),
      );
      final scrollbar = tester.widget<Scrollbar>(
        find.byKey(const ValueKey('schedule-period-scrollbar')),
      );
      expect(scrollbar.thumbVisibility, isTrue);
      expect(scrollbar.trackVisibility, isTrue);
      for (var i = 0; i < 30 && filter.hitTestable().evaluate().isEmpty; i++) {
        await tester.tap(find.byTooltip('Próximos períodos'));
        await tester.pumpAndSettle();
      }
      expect(
        filter.hitTestable(),
        findsOneWidget,
        reason: 'The period arrows must reach Optativas at the end',
      );
      final rect = tester.getRect(filter);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(scenario.$2.width));
      await tester.tap(filter);
      await tester.pumpAndSettle();
      final list = tester.widget<ListView>(find.byType(ListView));
      expect(
        list.childrenDelegate.estimatedChildCount,
        17,
      ); // Nine cards and eight separators.
      expect(
        tester
            .widgetList<ScheduleOfferingCard>(find.byType(ScheduleOfferingCard))
            .every((card) => card.offering.period == 0),
        isTrue,
      );

      final first = electives.first;
      final add = find.byTooltip('Adicionar ${first.name}');
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(state.schedule.map((d) => d.id), contains(first.id));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
