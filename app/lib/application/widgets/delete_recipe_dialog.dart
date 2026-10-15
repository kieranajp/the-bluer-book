import 'package:flutter/material.dart';

/// Pops `true` on confirm and `false`/`null` otherwise; the caller performs the
/// deletion.
class DeleteRecipeDialog extends StatelessWidget {
  final String recipeName;

  const DeleteRecipeDialog({super.key, required this.recipeName});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Delete recipe?'),
      content: Text(
        'Are you sure you want to delete "$recipeName"? '
        'You can find it again under archived recipes.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: scheme.error),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
