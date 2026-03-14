import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/recipe.dart';
import '../providers/recipe_providers.dart';
import '../widgets/meal_plan_card.dart';
import '../widgets/theme_selector_dialog.dart';
import '../styles/colours.dart';
import '../styles/text_styles.dart';
import '../styles/spacing.dart';

class MealPlanScreen extends ConsumerWidget {
  const MealPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favouriteRecipesAsync = ref.watch(favouriteRecipesProvider);

    ref.listen<AsyncValue<List<Recipe>>>(favouriteRecipesProvider, (previous, next) {
      if (next.hasError && !(previous?.hasError ?? false)) {
        final error = next.error;
        final message = error is Exception
            ? error.toString().replaceFirst('Exception: ', '')
            : 'Failed to load meal plan';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => ref.invalidate(favouriteRecipesProvider),
            ),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: context.colours.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: context.colours.background,
              elevation: 0,
              title: Text(
                'Meal Plan',
                style: TextStyles.appBarTitle(context),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.brightness_6),
                  tooltip: 'Theme',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const ThemeSelectorDialog(),
                    );
                  },
                ),
              ],
            ),
            favouriteRecipesAsync.when(
              data: (recipes) => recipes.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today, size: 48,
                                color: context.colours.textSecondary.withValues(alpha: 0.4)),
                            const SizedBox(height: Spacing.m),
                            Text(
                              'No recipes in your meal plan',
                              style: TextStyle(color: context.colours.textSecondary),
                            ),
                            const SizedBox(height: Spacing.xs),
                            Text(
                              'Star some recipes to build your meal plan',
                              style: TextStyle(
                                color: context.colours.textSecondary.withValues(alpha: 0.6),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.all(Spacing.m),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: Spacing.m,
                          crossAxisSpacing: Spacing.m,
                          childAspectRatio: 0.78,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => MealPlanCard(recipe: recipes[index]),
                          childCount: recipes.length,
                        ),
                      ),
                    ),
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off, size: 48,
                          color: context.colours.textSecondary.withValues(alpha: 0.4)),
                      const SizedBox(height: Spacing.m),
                      Text(
                        'Couldn\'t load meal plan',
                        style: TextStyle(color: context.colours.textSecondary),
                      ),
                      const SizedBox(height: Spacing.m),
                      OutlinedButton.icon(
                        onPressed: () => ref.invalidate(favouriteRecipesProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom spacing for FAB
            const SliverToBoxAdapter(
              child: SizedBox(height: Spacing.bottomSpacer),
            ),
          ],
        ),
      ),
    );
  }
}
