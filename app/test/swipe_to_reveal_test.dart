import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/application/styles/colours.dart';
import 'package:app/application/widgets/delete_recipe_dialog.dart';
import 'package:app/application/widgets/swipe_to_reveal.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: const [Colours.light]),
      home: Scaffold(body: child),
    );

void main() {
  group('SwipeToReveal', () {
    testWidgets('swiping left reveals the action and tapping it fires onAction',
        (tester) async {
      var fired = 0;
      await tester.pumpWidget(_wrap(
        SwipeToReveal(
          actionIcon: Icons.delete_outline_rounded,
          actionBackgroundColor: Colors.red,
          actionForegroundColor: Colors.white,
          actionSemanticLabel: 'Delete',
          onAction: () async => fired++,
          child: const SizedBox(
            height: 80,
            width: double.infinity,
            child: Text('Row content'),
          ),
        ),
      ));

      // Drag the row to the left to reveal the bin.
      await tester.drag(find.text('Row content'), const Offset(-120, 0));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(fired, 1);
    });
  });

  group('DeleteRecipeDialog', () {
    testWidgets('Delete returns true, Cancel returns false', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          ctx = context;
          return const SizedBox();
        }),
      ));

      // Confirm path.
      final confirmFuture = showDialog<bool>(
        context: ctx,
        builder: (_) => const DeleteRecipeDialog(recipeName: 'Apple pie'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Delete recipe?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(await confirmFuture, isTrue);

      // Cancel path.
      final cancelFuture = showDialog<bool>(
        context: ctx,
        builder: (_) => const DeleteRecipeDialog(recipeName: 'Apple pie'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await cancelFuture, isFalse);
    });
  });
}
