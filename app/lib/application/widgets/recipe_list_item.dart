import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/recipe.dart';
import '../screens/recipe_details_screen.dart';
import '../styles/colours.dart';
import '../styles/decorations.dart';
import '../styles/spacing.dart';
import '../styles/text_styles.dart';
import 'label_tag.dart';
import 'meal_plan_toggle_button.dart';

class RecipeListItem extends ConsumerWidget {
  final Recipe recipe;

  const RecipeListItem({super.key, required this.recipe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeDetailsScreen(recipe: recipe),
          ),
        );
      },
      child: Container(
        decoration: Decorations.card(context),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.s),
          child: Row(
            children: [
              _RecipeThumbnail(imageUrl: recipe.imageUrl),
              const SizedBox(width: Spacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _TitleRow(recipe: recipe),
                    const SizedBox(height: 4),
                    Text(
                      recipe.description,
                      style: TextStyles.caption(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: Spacing.xs),
                    _MetadataRow(recipe: recipe),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeThumbnail extends StatelessWidget {
  final String? imageUrl;

  const _RecipeThumbnail({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Spacing.thumbnailSize,
      height: Spacing.thumbnailSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: context.colours.border,
        image: imageUrl != null
            ? DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: imageUrl == null
          ? Icon(Icons.restaurant, size: 32,
              color: context.colours.textSecondary.withValues(alpha: 0.4))
          : null,
    );
  }
}

class _TitleRow extends StatelessWidget {
  final Recipe recipe;

  const _TitleRow({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            recipe.name,
            style: TextStyles.cardTitle(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: Spacing.xs),
        MealPlanStarIcon(
          uuid: recipe.uuid,
          isFavourite: recipe.isFavourite,
        ),
      ],
    );
  }
}

class _MetadataRow extends StatelessWidget {
  final Recipe recipe;

  const _MetadataRow({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final totalTime = recipe.preparationTime + recipe.cookingTime;

    return Wrap(
      spacing: Spacing.xs,
      runSpacing: Spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, size: 16, color: context.colours.textSecondary),
            const SizedBox(width: 4),
            Text('${totalTime}m', style: TextStyles.caption(context)),
          ],
        ),
        ...recipe.labels.take(3).map(
          (label) => LabelTagCompact(label: label),
        ),
      ],
    );
  }
}
