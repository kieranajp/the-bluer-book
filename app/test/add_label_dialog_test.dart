import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/application/widgets/add_label_dialog.dart';
import 'package:app/application/styles/colours.dart';

/// Opens an [AddLabelDialog] via showDialog from a host button, so the dialog
/// is on its own route and we can assert it dismisses after Add/Cancel.
Future<void> _openDialog(
  WidgetTester tester,
  void Function(String type, String name) onAdd,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: const [Colours.light]),
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AddLabelDialog(onAdd: onAdd),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('AddLabelDialog', () {
    testWidgets('Add reports the default type and entered name, then closes',
        (tester) async {
      final calls = <(String, String)>[];
      await _openDialog(tester, (type, name) => calls.add((type, name)));

      await tester.enterText(find.byType(TextField), 'main');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(calls, [('course', 'main')]);
      expect(find.byType(AddLabelDialog), findsNothing);
    });

    testWidgets('changing the type dropdown changes the reported type',
        (tester) async {
      final calls = <(String, String)>[];
      await _openDialog(tester, (type, name) => calls.add((type, name)));

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('cuisine').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'indian');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(calls, [('cuisine', 'indian')]);
    });

    testWidgets('submitting the name field via the keyboard reports and closes',
        (tester) async {
      final calls = <(String, String)>[];
      await _openDialog(tester, (type, name) => calls.add((type, name)));

      await tester.enterText(find.byType(TextField), 'vegan');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(calls, [('course', 'vegan')]);
      expect(find.byType(AddLabelDialog), findsNothing);
    });

    testWidgets('Cancel closes without reporting', (tester) async {
      final calls = <(String, String)>[];
      await _openDialog(tester, (type, name) => calls.add((type, name)));

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(calls, isEmpty);
      expect(find.byType(AddLabelDialog), findsNothing);
    });
  });
}
