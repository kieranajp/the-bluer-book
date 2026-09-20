import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/application/screens/app_shell/app_shell.dart';
import 'package:app/application/screens/sign_in/auth_gate.dart';
import 'package:app/application/screens/sign_in/sign_in_screen.dart';
import 'package:app/application/styles/app_theme.dart';
import 'package:app/application/styles/colours.dart';

Widget _themedApp(Widget home) => ProviderScope(
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light, Colours.light),
        home: home,
      ),
    );

void main() {
  testWidgets('empty storage settles on SignInScreen, not the app shell',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});

    // runAsync + a zero-delay so the gate's microtask keychain read lands
    // before we assert.
    await tester.runAsync(() async {
      await tester.pumpWidget(_themedApp(const AuthGate()));
      await Future<void>.delayed(Duration.zero);
      await tester.pump();
    });

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
  });

  testWidgets('renders the message when supplied', (tester) async {
    await tester.pumpWidget(_themedApp(const SignInScreen(message: 'Your session expired. Please sign in again.')));

    expect(find.text('Your session expired. Please sign in again.'), findsOneWidget);
  });

  testWidgets('omits the message when null', (tester) async {
    await tester.pumpWidget(_themedApp(const SignInScreen()));

    expect(find.text('Sign in to reach your recipes.'), findsOneWidget);
    expect(find.textContaining('session expired'), findsNothing);
  });
}
