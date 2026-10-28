import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ufape/core/models.dart';
import 'package:my_ufape/core/theme/app_theme.dart';
import 'package:my_ufape/features/academic/schedule/widgets/export_card.dart';
import 'package:my_ufape/features/academic/schedule/widgets/week_grid.dart';
import 'package:my_ufape/features/academic/schedule/widgets/week_layout.dart';
import 'package:my_ufape/services/widget_image.dart';

List<Discipline> referenceSchedule() {
  final fixture = jsonDecode(
    File('test/fixtures/schedule_bcc_2026_2.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final offerings = asList(fixture['schedule'])
      .map((d) => Discipline.fromJson(asMap(d)))
      .toList();
  return [
    for (final query in [
      'jogos digitais',
      'probabilidade',
      'projeto e analise',
      'rede de computadores',
      'interacao humano',
    ])
      offerings.firstWhere((d) => normalized(d.name).contains(query)),
  ];
}

Future<void> loadFont(WidgetTester tester) async {
  final font = FontLoader('Inter')
    ..addFont(
      Future.value(
        ByteData.sublistView(File('assets/fonts/Inter.ttf').readAsBytesSync()),
      ),
    );
  await tester.runAsync(font.load);
}

void main() {
  final saturday = Discipline(
    id: 'saturday',
    name: 'Aula no sábado',
    sessions: [Session(day: 6, time: '09:00 - 11:00')],
  );

  test('Saturday requires a selected, valid session', () {
    expect(displayedScheduleDays([]), hasLength(5));
    expect(displayedScheduleDays(referenceSchedule()), hasLength(5));
    expect(displayedScheduleDays([saturday]), hasLength(6));
    expect(
      displayedScheduleDays([
        Discipline(
          id: 'invalid',
          name: 'Inválida',
          sessions: [Session(day: 6, time: 'a confirmar')],
        ),
      ]),
      hasLength(5),
    );
  });

  testWidgets('Saturday appears and disappears with the scheduled class', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final selection = ValueNotifier<List<Discipline>>([]);
    addTearDown(selection.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ValueListenableBuilder<List<Discipline>>(
              valueListenable: selection,
              builder: (context, selected, _) => ScheduleWeekGrid(
                selected: selected,
                available: [saturday],
                shift: 'auto',
                scope: 'test',
                availableHeight: 900,
                onDetails: (_) {},
                onToggle: (_) {},
                disableMotion: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sábado'), findsNothing);
    selection.value = [saturday];
    await tester.pumpAndSettle();
    expect(find.text('Sábado'), findsOneWidget);
    final card = find.byKey(
      const ValueKey('schedule-session-saturday-6-09:00 - 11:00'),
    );
    expect(card, findsOneWidget);
    expect(tester.getRect(card).right, lessThanOrEqualTo(1440));
    selection.value = [];
    await tester.pumpAndSettle();
    expect(find.text('Sábado'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'export matches the document and is identical on phone and desktop',
    (tester) async {
      await loadFont(tester);
      Uint8List? desktop;
      for (final scenario in [
        (const Size(1440, 1200), Brightness.light, 1.0),
        (const Size(375, 844), Brightness.dark, 3.0),
      ]) {
        tester.view.physicalSize = scenario.$1;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final card = ScheduleExportCard(
          courseName: 'Bacharelado em Ciência da Computação',
          semester: '2026.2',
          selected: referenceSchedule(),
          date: DateTime(2026, 10, 18),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme(scenario.$2),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scenario.$3)),
              child: child!,
            ),
            home: Scaffold(
              body: Center(child: FittedBox(child: card)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(ScheduleExportCard));
        await tester.runAsync(
          () => precacheImage(
            const AssetImage(ScheduleExportCard.logoAsset),
            context,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('GRADE HORÁRIA'), findsOneWidget);
        expect(find.text('5 matérias matriculadas'), findsOneWidget);
        expect(find.text('SÁBADO'), findsNothing);
        expect(find.text('18/10/2026'), findsOneWidget);
        expect(find.byType(IconButton), findsNothing);
        final bytes = await tester.runAsync(
          () => renderWidgetPng(
            context,
            card,
            width: ScheduleExportCard.logicalWidth,
          ),
        );
        expect(bytes, isNotNull);
        final header = ByteData.sublistView(bytes!);
        expect(header.getUint32(16), 2300);
        expect(header.getUint32(20), greaterThan(1500));
        if (desktop == null) {
          desktop = bytes;
          if (const bool.fromEnvironment('SCHEDULE_EXPORT_SCREENSHOT')) {
            File('docs/screenshots/horarios-exportacao.png')
                .writeAsBytesSync(bytes);
          }
        } else {
          expect(bytes, orderedEquals(desktop));
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'export preserves complete titles and glyphs in narrow Saturday columns',
    (tester) async {
      await loadFont(tester);
      tester.view.physicalSize = const Size(1440, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final selected = [
        ...referenceSchedule(),
        Discipline(
          id: 'long-title',
          code: 'CCMP3099',
          name: 'Tópicos Especiais em Interação Humano-Computador e Aplicações Móveis',
          professor: 'Professora de Engenharia de Software',
          sessions: [Session(day: 6, time: '18:30 - 20:10')],
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ScheduleExportCard(
                courseName: 'Curso',
                semester: '2026.2',
                selected: selected,
                date: DateTime(2026, 10, 18),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final offering in selected) {
        for (final element
            in find.text(offering.name.toUpperCase()).evaluate()) {
          final paragraph = element.renderObject! as RenderParagraph;
          final painter = TextPainter(
            text: paragraph.text,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: paragraph.size.width);
          expect(paragraph.didExceedMaxLines, isFalse, reason: offering.name);
          expect(
            paragraph.size.height,
            greaterThanOrEqualTo(painter.height),
            reason: '${offering.name}: all lines must fit without clipping',
          );
          painter.dispose();
        }
      }
      expect(find.text('SÁBADO'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'export includes Saturday and disciplines without a usable time',
    (tester) async {
      await loadFont(tester);
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ScheduleExportCard(
                courseName: 'Curso',
                semester: '2026.2',
                date: DateTime(2026, 10, 18),
                selected: [
                  saturday,
                  Discipline(
                    id: 'unassigned',
                    name: 'Estágio a confirmar',
                    sessions: [],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('SÁBADO'), findsOneWidget);
      expect(find.text('DISCIPLINAS SEM HORÁRIO DEFINIDO'), findsOneWidget);
      expect(find.text('Estágio a confirmar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
