import 'package:flutter/material.dart';

/// Confirmation dialog shown before deleting a recipe. Presentational — it
/// pops `true` when the user confirms and `false`/`null` otherwise, leaving
/// the actual deletion to the caller.
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
