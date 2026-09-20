import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:app/main.dart';
import 'package:app/application/widgets/home_header.dart';
import 'package:app/application/widgets/home_hero.dart';
import 'package:app/infrastructure/auth/token_store.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});

    // Use runAsync because RecipeListNotifier fires a Dio request on
    // construction, which leaves a pending FakeTimer in the default
    // fake-async zone.
    await tester.runAsync(() async {
      // AuthGate renders the app shell only once it finds a token, so seed the
      // keychain with a live session before the app starts.
      await TokenStore().write(
        AuthSession(
          accessToken: 'test-access-token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );

      await tester.pumpWidget(const ProviderScope(child: BluerBook()));
      // The gate reads the keychain off a microtask; let it land.
      await Future<void>.delayed(Duration.zero);
      await tester.pump();
    });

    // Home renders its header + serif hero as soon as the tree is laid out,
    // before any data has arrived.
    expect(find.byType(HomeHeader), findsOneWidget);
    expect(find.byType(HomeHero), findsOneWidget);
  });
}
