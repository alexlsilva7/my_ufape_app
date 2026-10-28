import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ufape/core/app_state.dart';
import 'package:my_ufape/features/academic/schedule/widgets/session_motion.dart';
import 'package:my_ufape/features/academic/schedule/schedule_view.dart';
import 'package:my_ufape/core/theme/app_theme.dart';

import 'academic_ui_test.dart' show useProgressFilePicker;
import 'core_test.dart' as fixture;

final _session = find.byKey(
  const ValueKey('schedule-session-one-1-07:30 - 09:30'),
);

Future<AppState> _mount(
  WidgetTester tester, {
  bool reduced = false,
  bool accessible = false,
  bool phone = false,
}) async {
  tester.view.physicalSize = phone
      ? const Size(390, 844)
      : const Size(1440, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final state = await fixture.createState();
  addTearDown(state.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduced,
          accessibleNavigation: accessible,
        ),
        child: child!,
      ),
      home: Scaffold(body: ScheduleView(viewModel: state.timetable)),
    ),
  );
  await tester.pumpAndSettle();
  return state;
}

double _opacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find
          .descendant(of: _session, matching: find.byType(FadeTransition))
          .first,
    )
    .opacity
    .value;

void main() {
  testWidgets('sessions fade in and leave without active controls', (
    tester,
  ) async {
    final state = await _mount(tester);
    await tester.tap(find.text('Oferta one'));
    await tester.pump();
    expect(state.schedule.length, 1);
    expect(_opacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 80));
    expect(_opacity(tester), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(_opacity(tester), 1);
    await tester.tap(find.byTooltip('Remover Oferta one').last);
    await tester.pump();
    expect(state.schedule, isEmpty);
    expect(_session, findsOneWidget);
    expect(
      tester
          .widget<IgnorePointer>(
            find
                .descendant(of: _session, matching: find.byType(IgnorePointer))
                .first,
          )
          .ignoring,
      isTrue,
    );
    expect(
      tester
          .widget<ExcludeFocus>(
            find
                .descendant(of: _session, matching: find.byType(ExcludeFocus))
                .first,
          )
          .excluding,
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 60));
    expect(_opacity(tester), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(_session, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rapid changes reverse an exit without duplicate or lost sessions',
    (tester) async {
      final state = await _mount(tester);
      await tester.tap(find.text('Oferta one'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      await tester.tap(find.text('Oferta one'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(find.text('Oferta one'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(state.schedule.map((d) => d.id), ['one']);
      expect(_session, findsOneWidget);
      expect(_opacity(tester), 1);
      await tester.tap(find.byTooltip('Marcar como concluída').first);
      await tester.pump();
      expect(state.schedule, isEmpty);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shift changes move stable sessions without replaying entry', (
    tester,
  ) async {
    await _mount(tester);
    await tester.tap(find.text('Oferta one'));
    await tester.pumpAndSettle();
    final start = tester.getRect(_session);
    await tester.ensureVisible(
      find.byKey(const ValueKey('schedule-shift-all')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('schedule-shift-all')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final middle = tester.getRect(_session);
    expect(_opacity(tester), 1);
    await tester.pumpAndSettle();
    final end = tester.getRect(_session);
    expect(start.height, greaterThan(end.height));
    expect(middle.height, inExclusiveRange(end.height, start.height));
    await tester.ensureVisible(
      find.byKey(const ValueKey('schedule-shift-noite')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('schedule-shift-noite')));
    await tester.pumpAndSettle();
    expect(_session, findsNothing);
    await tester.ensureVisible(
      find.byKey(const ValueKey('schedule-shift-auto')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('schedule-shift-auto')));
    await tester.pumpAndSettle();
    expect(_session, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('departing search results cannot change the schedule', (
    tester,
  ) async {
    final state = await _mount(tester);
    await tester.enterText(find.byType(TextField), 'adjacent');
    await tester.pump();
    final outgoing = find.text('Oferta one');
    expect(outgoing, findsOneWidget);
    final ignored = find.ancestor(
      of: outgoing,
      matching: find.byWidgetPredicate(
        (widget) => widget is IgnorePointer && widget.ignoring,
      ),
    );
    expect(ignored, findsWidgets);
    final unfocused = find.ancestor(
      of: outgoing,
      matching: find.byType(ExcludeFocus),
    );
    expect(unfocused, findsWidgets);
    await tester.pumpAndSettle();
    expect(outgoing, findsNothing);
    await tester.tap(find.text('Oferta adjacent'));
    await tester.pumpAndSettle();
    expect(state.schedule.map((d) => d.id), ['adjacent']);
    expect(tester.takeException(), isNull);
  });

  for (final accessible in [false, true]) {
    testWidgets(
      'motion preference accessible=$accessible updates immediately',
      (tester) async {
        final state = await _mount(
          tester,
          reduced: !accessible,
          accessible: accessible,
        );
        await tester.tap(find.text('Oferta one'));
        await tester.pump();
        expect(_session, findsOneWidget);
        expect(
          find.descendant(of: _session, matching: find.byType(FadeTransition)),
          findsNothing,
        );
        await tester.tap(find.text('Oferta one'));
        await tester.pump();
        expect(state.schedule, isEmpty);
        expect(_session, findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('phone tabs respect reduced motion', (tester) async {
    await _mount(tester, reduced: true, phone: true);
    await tester.tap(find.text('Oferta one'));
    await tester.pump();
    await tester.tap(find.text('Minha grade (1)'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Segunda').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PNG export settles active sessions before capturing', (
    tester,
  ) async {
    final picker = useProgressFilePicker();
    await _mount(tester);
    await tester.tap(find.text('Oferta one'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(_opacity(tester), lessThan(1));
    await tester.tap(find.text('Salvar imagem'));
    await tester.pump();
    expect(
      tester
          .widget<ScheduleSessionLayer>(find.byType(ScheduleSessionLayer))
          .duration,
      Duration.zero,
    );
    expect(
      find.descendant(of: _session, matching: find.byType(FadeTransition)),
      findsNothing,
    );
    await tester.pump();
    for (var i = 0; i < 10 && picker.exportedBytes == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
    expect(picker.exportedName, 'grade-a-2026.1.png');
    expect(picker.exportedBytes!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(picker.exportedBytes!.buffer.asByteData().getUint32(16), 2300);
    await tester.pumpAndSettle();
    expect(_opacity(tester), 1);
    expect(tester.takeException(), isNull);
  });
}
