import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../styles/colours.dart';
import '../../styles/spacing.dart';
import '../../styles/text_styles.dart';
import '../../widgets/brand_mark.dart';
import 'login_error_banner.dart';

/// First screen a brand-new (or signed-out) user sees. Single "Sign in
/// with Google" action that kicks off the Kratos OIDC dance via
/// AuthNotifier. Errors from the previous attempt come in via
/// [LoginScreen.error] and render as an inline banner above the
/// button.
class LoginScreen extends ConsumerWidget {
  final String? error;

  const LoginScreen({super.key, this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.colours.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.l),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BrandMark(size: 96),
                  const SizedBox(height: Spacing.l),
                  Text(
                    'The Bluer Book',
                    textAlign: TextAlign.center,
                    style: TextStyles.heroDisplay(context),
                  ),
                  const SizedBox(height: Spacing.s),
                  Text(
                    'Your household cookbook.',
                    textAlign: TextAlign.center,
                    style: TextStyles.bodySecondary(context),
                  ),
                  const SizedBox(height: Spacing.xl),
                  if (error != null) ...[
                    LoginErrorBanner(message: error!),
                    const SizedBox(height: Spacing.m),
                  ],
                  FilledButton.icon(
                    onPressed: () => ref.read(authProvider.notifier).signInWithGoogle(),
                    icon: const Icon(Icons.login),
                    label: const Text('Sign in with Google'),
                  ),
                  const SizedBox(height: Spacing.s),
                  Text(
                    "We use Google to verify it's you. We never see your password.",
                    textAlign: TextAlign.center,
                    style: TextStyles.caption(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
