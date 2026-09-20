import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../widgets/brand_loader.dart';
import '../app_shell/app_shell.dart';
import 'sign_in_screen.dart';

/// Stands between the app and anybody who has not signed in. It sits at
/// `MaterialApp.home` so no other screen has to think about auth.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(authProvider)) {
      AuthRestoring() => const Scaffold(body: Center(child: BrandLoader())),
      AuthSignedOut(message: final message) => SignInScreen(message: message),
      AuthSignedIn() => const AppShell(),
    };
  }
}
