import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/recipe.dart';
import '../providers/recipe_providers.dart';
import '../widgets/brand_mark.dart';
import '../widgets/meal_plan_card.dart';
import '../widgets/empty_state.dart';
import '../styles/colours.dart';
import '../styles/text_styles.dart';
import '../styles/spacing.dart';
import 'shopping_list_screen.dart';

class MealPlanScreen extends ConsumerWidget {
  const MealPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealPlanRecipesAsync = ref.watch(mealPlanRecipesProvider);

    ref.listen<AsyncValue<List<Recipe>>>(mealPlanRecipesProvider, (previous, next) {
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
              onPressed: () => ref.invalidate(mealPlanRecipesProvider),
            ),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: context.colours.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(mealPlanRecipesProvider);
            await ref.read(mealPlanRecipesProvider.future);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                  icon: const Icon(Icons.shopping_cart_outlined),
                  tooltip: 'Shopping list',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ShoppingListScreen(),
                    ),
                  ),
                ),
              ],
            ),
            mealPlanRecipesAsync.when(
              data: (recipes) => recipes.isEmpty
                  ? const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.calendar_today,
                        title: 'No recipes in your meal plan',
                        subtitle: 'Star some recipes to build your meal plan',
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.all(Spacing.m),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: Spacing.l,
                          crossAxisSpacing: Spacing.m,
                          childAspectRatio: 0.72,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => MealPlanCard(
                            recipe: recipes[index],
                            mirror: index.isOdd,
                          ),
                          childCount: recipes.length,
                        ),
                      ),
                    ),
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: BrandLoader()),
              ),
              error: (error, stack) => SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.cloud_off,
                  title: 'Couldn\'t load meal plan',
                  action: OutlinedButton.icon(
                    onPressed: () => ref.invalidate(mealPlanRecipesProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
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
      ),
    );
  }
}
