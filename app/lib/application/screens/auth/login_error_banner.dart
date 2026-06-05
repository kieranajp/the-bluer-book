import 'package:flutter/material.dart';

import '../../styles/spacing.dart';
import '../../styles/text_styles.dart';

/// Inline error shown above the sign-in button after a failed login.
/// Rendered in [LoginScreen] when [LoginScreen.error] is non-null —
/// e.g. the user dismissed the browser dance, Kratos rejected the
/// callback, or a 401 from the backend dropped them back here.
class LoginErrorBanner extends StatelessWidget {
  final String message;
  const LoginErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.s),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 20),
          const SizedBox(width: Spacing.xs),
          Expanded(
            child: Text(
              message,
              style: TextStyles.bodySecondary(context).copyWith(
                color: scheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
