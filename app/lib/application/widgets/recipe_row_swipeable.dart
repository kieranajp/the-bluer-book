import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/recipe.dart';
import '../providers/recipe_providers.dart';
import '../styles/colours.dart';
import 'delete_recipe_dialog.dart';
import 'recipe_row.dart';
import 'swipe_to_reveal.dart';

/// A [RecipeRow] you can swipe left to reveal a bin. Tapping the bin asks for
/// confirmation, then deletes (archives) the recipe via [recipeListProvider].
class RecipeRowSwipeable extends ConsumerWidget {
  final Recipe recipe;
  final bool isLast;

  const RecipeRowSwipeable({
    super.key,
    required this.recipe,
    this.isLast = false,
  });

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteRecipeDialog(recipeName: recipe.name),
    );
    if (confirmed != true) return;

    try {
      await ref.read(recipeListProvider.notifier).deleteRecipe(recipe.uuid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${recipe.name}"'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete recipe'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return SwipeToReveal(
      actionIcon: Icons.delete_outline_rounded,
      actionBackgroundColor: scheme.error,
      actionForegroundColor: scheme.onError,
      actionSemanticLabel: 'Delete ${recipe.name}',
      childBackgroundColor: context.colours.background,
      onAction: () => _confirmAndDelete(context, ref),
      child: RecipeRow(recipe: recipe, isLast: isLast),
    );
  }
}
