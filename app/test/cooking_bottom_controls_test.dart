import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/application/screens/cooking_mode/cooking_bottom_controls.dart';
import 'package:app/application/screens/cooking_mode/cooking_prev_button.dart';
import 'package:app/application/styles/colours.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: const [Colours.light]),
      home: Scaffold(body: child),
    );

CookingBottomControls _controls({
  required int index,
  required int total,
  VoidCallback? onPrev,
  VoidCallback? onNext,
  VoidCallback? onFinish,
}) =>
    CookingBottomControls(
      index: index,
      total: total,
      onPrev: onPrev ?? () {},
      onNext: onNext ?? () {},
      onFinish: onFinish ?? () {},
    );

void main() {
  group('CookingBottomControls', () {
    testWidgets('shows "Next step" (not "Finish") on a middle step',
        (tester) async {
      await tester.pumpWidget(_wrap(_controls(index: 0, total: 3)));

      expect(find.text('Next step'), findsOneWidget);
      expect(find.text('Finish'), findsNothing);
    });

    testWidgets('shows "Finish" on the last step', (tester) async {
      await tester.pumpWidget(_wrap(_controls(index: 2, total: 3)));

      expect(find.text('Finish'), findsOneWidget);
      expect(find.text('Next step'), findsNothing);
    });

    testWidgets('tapping advances via onNext on a non-last step',
        (tester) async {
      var next = 0;
      var finish = 0;
      await tester.pumpWidget(_wrap(_controls(
        index: 0,
        total: 3,
        onNext: () => next++,
        onFinish: () => finish++,
      )));

      await tester.tap(find.text('Next step'));

      expect(next, 1);
      expect(finish, 0);
    });

    testWidgets('tapping finishes via onFinish on the last step',
        (tester) async {
      var next = 0;
      var finish = 0;
      await tester.pumpWidget(_wrap(_controls(
        index: 2,
        total: 3,
        onNext: () => next++,
        onFinish: () => finish++,
      )));

      await tester.tap(find.text('Finish'));

      expect(finish, 1);
      expect(next, 0);
    });

    testWidgets('prev is disabled on the first step', (tester) async {
      var prev = 0;
      await tester.pumpWidget(_wrap(_controls(
        index: 0,
        total: 3,
        onPrev: () => prev++,
      )));

      await tester.tap(find.byType(CookingPrevButton));

      expect(prev, 0);
    });

    testWidgets('prev fires on a later step', (tester) async {
      var prev = 0;
      await tester.pumpWidget(_wrap(_controls(
        index: 1,
        total: 3,
        onPrev: () => prev++,
      )));

      await tester.tap(find.byType(CookingPrevButton));

      expect(prev, 1);
    });
  });
}
