import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Use runAsync because RecipeListNotifier fires a Dio request on
    // construction, which leaves a pending FakeTimer in the default
    // fake-async zone.
    await tester.runAsync(() async {
      await tester.pumpWidget(const ProviderScope(child: BluerBook()));
    });

    // Verify that the app title is present
    expect(find.text('My Kitchen'), findsOneWidget);
  });
}
