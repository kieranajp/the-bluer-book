import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/recipe.dart';
import '../screens/recipe_details_screen.dart';
import '../styles/colours.dart';
import '../providers/recipe_providers.dart';

class RecipeListItem extends ConsumerWidget {
  final Recipe recipe;

  const RecipeListItem({super.key, required this.recipe});

  Color _getLabelColor(String? colour) {
    if (colour == null) return const Color(0xFF4E6983);

    try {
      if (colour.startsWith('#')) {
        return Color(int.parse(colour.substring(1), radix: 16) + 0xFF000000);
      }
      return const Color(0xFF4E6983);
    } catch (e) {
      return const Color(0xFF4E6983);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalTime = recipe.preparationTime + recipe.cookingTime;

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
        decoration: BoxDecoration(
          color: context.colours.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colours.border),
          boxShadow: [
            BoxShadow(
              color: context.colours.shadow,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: context.colours.border,
                image: recipe.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(recipe.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: recipe.imageUrl == null
                  ? Icon(Icons.restaurant, size: 32, color: context.colours.textSecondary.withValues(alpha: 0.4))
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          recipe.name,
                          style: GoogleFonts.workSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: context.colours.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          final notifier = ref.read(recipeListProvider.notifier);
                          try {
                            await notifier.toggleMealPlan(recipe.uuid);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    recipe.isFavourite
                                        ? 'Removed from meal plan'
                                        : 'Added to meal plan',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to update meal plan'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                        child: Icon(
                          recipe.isFavourite ? Icons.star : Icons.star_border,
                          color: recipe.isFavourite
                              ? context.colours.primary
                              : context.colours.textSecondary.withValues(alpha: 0.3),
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recipe.description,
                    style: GoogleFonts.workSans(
                      fontSize: 12,
                      color: context.colours.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 16,
                            color: context.colours.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${totalTime}m',
                            style: GoogleFonts.workSans(
                              fontSize: 12,
                              color: context.colours.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      ...recipe.labels.take(3).map((label) {
                        final labelColor = _getLabelColor(label.colour);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: labelColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            label.name.toUpperCase(),
                            style: GoogleFonts.workSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: labelColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
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
