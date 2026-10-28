import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ufape/features/home/widgets/home_entrance.dart';
import 'package:my_ufape/features/home/widgets/home_visuals.dart';

void main() {
  testWidgets(
    'home entrance staggers sections and does not replay on theme updates',
    (tester) async {
      Widget app(Brightness brightness) => MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: const Column(
          children: [
            HomeEntrance(child: Text('Hero')),
            HomeEntrance(order: 2, child: Text('Calendar')),
          ],
        ),
      );
      double opacity(int order) => tester
          .widget<FadeTransition>(
            find.descendant(
              of: find.byWidgetPredicate(
                (widget) => widget is HomeEntrance && widget.order == order,
              ),
              matching: find.byType(FadeTransition),
            ),
          )
          .opacity
          .value;
      await tester.pumpWidget(app(Brightness.light));
      expect(opacity(0), 0);
      expect(opacity(2), 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacity(0), inExclusiveRange(0, 1));
      expect(opacity(2), 0);
      await tester.pumpAndSettle();
      expect(opacity(2), 1);
      await tester.pumpWidget(app(Brightness.dark));
      expect(opacity(0), 1);
      expect(opacity(2), 1);
      await tester.pumpAndSettle();
    },
  );

  for (final accessible in [false, true]) {
    testWidgets(
      'home entrance honors ${accessible ? 'accessible navigation' : 'reduced motion'} during animation',
      (tester) async {
        Widget app(bool reduced) => MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: !accessible && reduced,
              accessibleNavigation: accessible && reduced,
            ),
            child: child!,
          ),
          home: const HomeEntrance(order: 3, child: Text('Ready')),
        );
        await tester.pumpWidget(app(false));
        await tester.pump(const Duration(milliseconds: 80));
        await tester.pumpWidget(app(true));
        final fade = tester.widget<FadeTransition>(
          find.descendant(
            of: find.byType(HomeEntrance),
            matching: find.byType(FadeTransition),
          ),
        );
        expect(fade.opacity.value, 1);
        await tester.pumpAndSettle();
        await tester.pumpWidget(app(false));
        expect(fade.opacity.value, 1);
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets('home card gives hover, canceled press and keyboard feedback', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 240,
            height: 120,
            child: HomeButton(
              accent: Colors.indigo,
              onTap: () => taps++,
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(HomeButton)));
    await tester.pumpAndSettle();
    final container = find.descendant(
      of: find.byType(HomeButton),
      matching: find.byType(AnimatedContainer),
    );
    expect(
      tester.widget<AnimatedContainer>(container).transform!.storage[13],
      -3,
    );
    final press = await tester.startGesture(
      tester.getCenter(find.byType(HomeButton)),
    );
    await tester.pump();
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      .985,
    );
    await press.cancel();
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    expect(taps, 0);
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(
      tester.widget<AnimatedContainer>(container).transform!.storage[13],
      -3,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}
