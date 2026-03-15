import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/recipe_providers.dart';
import '../styles/colours.dart';
import '../styles/text_styles.dart';
import '../styles/spacing.dart';

/// Shared helper that performs the meal plan toggle and shows a snackbar.
/// Used by both the icon button (list item) and the full-width button (detail screen).
Future<void> _toggleMealPlan({
  required WidgetRef ref,
  required BuildContext context,
  required String uuid,
  required bool isCurrentlyInMealPlan,
}) async {
  final notifier = ref.read(recipeListProvider.notifier);
  try {
    await notifier.toggleMealPlan(uuid);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCurrentlyInMealPlan
                ? 'Removed from meal plan'
                : 'Added to meal plan',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update meal plan'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

/// A small star icon for toggling meal plan status (used in list items).
class MealPlanStarIcon extends ConsumerWidget {
  final String uuid;
  final bool isFavourite;

  const MealPlanStarIcon({
    super.key,
    required this.uuid,
    required this.isFavourite,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _toggleMealPlan(
        ref: ref,
        context: context,
        uuid: uuid,
        isCurrentlyInMealPlan: isFavourite,
      ),
      child: Icon(
        isFavourite ? Icons.star : Icons.star_border,
        color: isFavourite
            ? context.colours.primary
            : context.colours.textSecondary.withValues(alpha: 0.3),
        size: 24,
      ),
    );
  }
}

/// A full-width elevated button for toggling meal plan status (used in detail screen).
class MealPlanFullButton extends ConsumerWidget {
  final String uuid;
  final bool isFavourite;

  const MealPlanFullButton({
    super.key,
    required this.uuid,
    required this.isFavourite,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.m),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: () => _toggleMealPlan(
            ref: ref,
            context: context,
            uuid: uuid,
            isCurrentlyInMealPlan: isFavourite,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: isFavourite
                ? context.colours.textSecondary.withValues(alpha: 0.3)
                : context.colours.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isFavourite ? Icons.star : Icons.star_border,
                size: 20,
              ),
              const SizedBox(width: Spacing.xs),
              Text(
                isFavourite ? 'Remove from Meal Plan' : 'Add to Meal Plan',
                style: TextStyles.buttonText(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
