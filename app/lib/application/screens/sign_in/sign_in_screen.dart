import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../styles/spacing.dart';
import '../../styles/text_styles.dart';
import '../../widgets/brand_mark.dart';

/// The only thing a signed-out app offers: a hand-off to Authentik. The button
/// opens the system browser; AppAuth brings the result back.
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key, this.message});

  /// Why the last session ended, when it ended badly.
  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 96),
              const SizedBox(height: Spacing.l),
              Text('The Bluer Book', style: TextStyles.pageTitle(context)),
              const SizedBox(height: Spacing.xs),
              Text(
                'Sign in to reach your recipes.',
                style: TextStyles.bodySecondary(context),
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: Spacing.m),
                Text(
                  message!,
                  style: TextStyles.bodySecondary(context).copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: Spacing.xl),
              FilledButton(
                onPressed: () => ref.read(authProvider.notifier).signIn(),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
