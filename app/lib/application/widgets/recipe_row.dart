import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/recipe.dart';
import '../providers/pantry_providers.dart';
import '../screens/recipe_details_screen.dart';
import '../styles/colours.dart';
import '../styles/label_colours.dart';
import '../styles/shapes.dart';
import '../utils/cookability.dart';
import '../utils/time_format.dart';
import 'meal_plan_toggle_button.dart';
import 'recipe_cook_badge.dart';
import 'recipe_image.dart';

/// Compact recipe row used in the home screen's "All recipes" list.
/// 72×72 squircle thumb + two-line title + description + meta chips.
class RecipeRow extends ConsumerWidget {
  final Recipe recipe;
  final bool isLast;

  const RecipeRow({super.key, required this.recipe, this.isLast = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colours;
    final totalTime = recipe.preparationTime + recipe.cookingTime;
    final pantry = ref.watch(pantryProvider).valueOrNull ?? const <String>{};
    final cook = cookabilityOf(recipe, pantry);
    // Only meaningful once the pantry has something in it.
    final showCookBadge = pantry.isNotEmpty && cook.total > 0;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecipeDetailsScreen(recipe: recipe),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: isLast
                ? BorderSide.none
                : BorderSide(
                    color: c.outlineVariant.withValues(alpha: 0.33),
                  ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: RecipeImage(
                imageUrl: recipe.imageUrl,
                borderRadius: Shapes.squircle(22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          recipe.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      MealPlanStarIcon(
                        uuid: recipe.uuid,
                        isInMealPlan: recipe.isInMealPlan,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (recipe.description.isNotEmpty)
                    Text(
                      recipe.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: c.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 12, color: c.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        formatMinutes(totalTime),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: c.textSecondary,
                        ),
                      ),
                      if (showCookBadge) ...[
                        const SizedBox(width: 8),
                        RecipeCookBadge(cook: cook),
                      ],
                      if (recipe.labels.isNotEmpty) const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 20,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: recipe.labels.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 6),
                            itemBuilder: (context, i) {
                              final label = recipe.labels[i];
                              final tone = labelToneFor(context, label.type);
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: tone.background,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  labelDisplayName(label.name).toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: tone.foreground,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
