import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/ingredient.dart';
import '../../providers/edit_recipe_provider.dart';
import '../../providers/recipe_providers.dart';
import '../../widgets/ingredient_edit_card.dart';
import '../../styles/colours.dart';
import '../../styles/text_styles.dart';
import '../../styles/spacing.dart';

class EditRecipeIngredientsSection extends ConsumerWidget {
  final EditRecipeState editState;
  final EditRecipeNotifier notifier;

  const EditRecipeIngredientsSection({
    super.key,
    required this.editState,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availableUnits =
        ref.watch(unitsProvider).valueOrNull ?? <IngredientUnit>[];
    final availableIngredients =
        ref.watch(ingredientsProvider).valueOrNull ?? <IngredientDetail>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Ingredients', style: TextStyles.sectionHeading(context)),
            const Spacer(),
            IconButton(
              onPressed: notifier.addIngredient,
              icon: Icon(Icons.add_circle_outline,
                  color: context.colours.primary),
            ),
          ],
        ),
        const SizedBox(height: Spacing.xs),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: editState.ingredients.length,
          onReorderItem: notifier.reorderIngredients,
          buildDefaultDragHandles: false,
          proxyDecorator: (child, index, animation) => Material(
            color: Colors.transparent,
            child: child,
          ),
          itemBuilder: (context, i) {
            return IngredientEditCard(
              key: ValueKey(editState.ingredients[i].id),
              index: i,
              ingredient: editState.ingredients[i],
              availableUnits: availableUnits,
              availableIngredients: availableIngredients,
              onChanged: (updated) => notifier.updateIngredient(i, updated),
              onDelete: () => notifier.removeIngredient(i),
            );
          },
        ),
      ],
    );
  }
}
