import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/recipe_providers.dart';
import '../styles/colours.dart';

/// A small star icon for toggling meal plan status (used in list items).
class MealPlanStarIcon extends ConsumerWidget {
  final String uuid;
  final bool isInMealPlan;

  const MealPlanStarIcon({
    super.key,
    required this.uuid,
    required this.isInMealPlan,
  });

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(recipeListProvider.notifier);
    try {
      await notifier.toggleMealPlan(uuid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isInMealPlan ? 'Removed from meal plan' : 'Added to meal plan',
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _toggle(context, ref),
      child: Icon(
        isInMealPlan ? Icons.star_rounded : Icons.star_outline_rounded,
        color: isInMealPlan
            ? context.colours.tertiary
            : context.colours.textSecondary,
        size: 22,
      ),
    );
  }
}
