import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/recipe_providers.dart';
import '../providers/tab_provider.dart';
import '../styles/colours.dart';
import 'carousel_dots.dart';
import 'meal_plan_carousel_card.dart';
import 'meal_plan_empty.dart';
import 'section_label.dart';

/// The data-driven contents of the meal-plan carousel: loads the planned
/// recipes and renders the section label, the snap carousel, and the dots.
/// Page state (controller + active index) is owned by the parent and passed in.
class MealPlanCarouselBody extends ConsumerWidget {
  final PageController controller;
  final int active;
  final ValueChanged<int> onPageChanged;

  const MealPlanCarouselBody({
    super.key,
    required this.controller,
    required this.active,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealPlanAsync = ref.watch(mealPlanRecipesProvider);

    return mealPlanAsync.when(
      data: (recipes) {
        if (recipes.isEmpty) return const MealPlanEmpty();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(
              title: 'On the meal plan',
              action: 'View meal plan →',
              onAction: () =>
                  ref.read(selectedTabProvider.notifier).select(1),
            ),
            SizedBox(
              height: 320,
              child: PageView.builder(
                controller: controller,
                padEnds: false,
                onPageChanged: onPageChanged,
                itemCount: recipes.length,
                itemBuilder: (context, i) => Padding(
                  padding: EdgeInsets.fromLTRB(
                    i == 0 ? 20 : 7,
                    0,
                    i == recipes.length - 1 ? 20 : 7,
                    0,
                  ),
                  child: MealPlanCarouselCard(recipe: recipes[i]),
                ),
              ),
            ),
            CarouselDots(count: recipes.length, active: active),
            const SizedBox(height: 20),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 320,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          "Couldn't load meal plan",
          style: TextStyle(color: context.colours.textSecondary),
        ),
      ),
    );
  }
}
