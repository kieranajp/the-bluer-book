import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../app_shell/app_shell.dart';
import 'auth_splash.dart';
import 'login_screen.dart';

/// Top-of-app gate that decides whether to show the login screen or
/// the main app shell based on the current [AuthState]. Swapped in for
/// AppShell as `MaterialApp.home`. Keeps auth decisions out of every
/// individual screen.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return switch (auth) {
      AuthStateLoading() => const AuthSplash(),
      AuthStateSignedOut(error: final err) => LoginScreen(error: err),
      AuthStateSignedIn() => const AppShell(),
    };
  }
}
