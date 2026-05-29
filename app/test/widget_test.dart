import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/main.dart';
import 'package:app/application/widgets/home_header.dart';
import 'package:app/application/widgets/home_hero.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Use runAsync because RecipeListNotifier fires a Dio request on
    // construction, which leaves a pending FakeTimer in the default
    // fake-async zone.
    await tester.runAsync(() async {
      await tester.pumpWidget(const ProviderScope(child: BluerBook()));
    });

    // Home renders its header + serif hero as soon as the tree is laid out,
    // before any data has arrived.
    expect(find.byType(HomeHeader), findsOneWidget);
    expect(find.byType(HomeHero), findsOneWidget);
  });
}
