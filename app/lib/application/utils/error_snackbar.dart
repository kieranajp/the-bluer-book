import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Listens to an [AsyncValue] provider and shows a floating [SnackBar]
/// with a formatted error message and a retry action when the provider
/// transitions into an error state.
void listenForErrorSnackbar<T>(
  WidgetRef ref,
  BuildContext context, {
  required ProviderListenable<AsyncValue<T>> provider,
  required String fallbackMessage,
  required VoidCallback onRetry,
}) {
  ref.listen<AsyncValue<T>>(provider, (previous, next) {
    if (next.hasError && !(previous?.hasError ?? false)) {
      final error = next.error;
      final message = error is Exception
          ? error.toString().replaceFirst('Exception: ', '')
          : fallbackMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: onRetry,
          ),
        ),
      );
    }
  });
}
