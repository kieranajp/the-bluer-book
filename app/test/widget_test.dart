import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/main.dart';
import 'package:app/domain/me.dart';
import 'package:app/application/providers/auth_providers.dart';
import 'package:app/application/screens/auth/login_screen.dart';
import 'package:app/application/widgets/home_header.dart';
import 'package:app/application/widgets/home_hero.dart';
import 'package:app/infrastructure/auth/session_storage.dart';

/// SessionStorage that never touches the platform keychain — the
/// flutter_secure_storage method channel isn't wired up under
/// `flutter test`, so the real one throws MissingPluginException.
/// Returning a null token drives AuthGate to its signed-out branch.
class _EmptySessionStorage extends SessionStorage {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String token) async {}
  @override
  Future<void> clear() async {}
}

/// Pins the auth state to signed-in so we can exercise the app shell /
/// home tree without running the real Kratos resume side-effects.
class _SignedInAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthStateSignedIn(Me(homes: []));
}

void main() {
  testWidgets('cold start with no session lands on the login screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(_EmptySessionStorage()),
        ],
        child: const BluerBook(),
      ),
    );

    // AuthGate starts on the splash, then the resume microtask resolves
    // to signed-out once the (empty) session read completes.
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeHeader), findsNothing);
  });

  testWidgets('a valid session renders the home header + hero',
      (WidgetTester tester) async {
    // Use runAsync because RecipeListNotifier fires a Dio request on
    // construction, which leaves a pending FakeTimer in the default
    // fake-async zone.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_SignedInAuthNotifier.new),
            sessionStorageProvider.overrideWithValue(_EmptySessionStorage()),
          ],
          child: const BluerBook(),
        ),
      );
    });

    // Home renders its header + serif hero as soon as the tree is laid
    // out, before any recipe data has arrived.
    expect(find.byType(HomeHeader), findsOneWidget);
    expect(find.byType(HomeHero), findsOneWidget);
  });
}
