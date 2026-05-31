import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/recipe_providers.dart';
import '../providers/tab_provider.dart';
import '../styles/colours.dart';
import '../styles/shapes.dart';
import 'meal_plan_carousel_card.dart';
import 'section_label.dart';

/// Horizontal, snap-aligned carousel of meal-plan recipes. First card uses
/// ~86% of viewport width so the next one peeks from the right edge — the
/// strongest tactile cue that the row scrolls.
class MealPlanCarousel extends ConsumerStatefulWidget {
  const MealPlanCarousel({super.key});

  @override
  ConsumerState<MealPlanCarousel> createState() => _MealPlanCarouselState();
}

class _MealPlanCarouselState extends ConsumerState<MealPlanCarousel> {
  late final PageController _controller;
  int _active = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.86);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // While a search is active the meal plan recedes — it collapses and fades
    // out of the way so the results below rise to the top and it's obvious the
    // search did something. The carousel stays in the tree (and keeps its page
    // position) so it springs back when the query clears.
    final isSearching = ref.watch(searchQueryProvider).isNotEmpty;

    return ClipRect(
      child: AnimatedAlign(
        alignment: Alignment.topCenter,
        heightFactor: isSearching ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
        child: AnimatedOpacity(
          opacity: isSearching ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 180),
          child: IgnorePointer(
            ignoring: isSearching,
            // Top gap lives here so it recedes together with the carousel
            // rather than leaving a stranded strip of whitespace.
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _content(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final mealPlanAsync = ref.watch(mealPlanRecipesProvider);

    return mealPlanAsync.when(
      data: (recipes) {
        if (recipes.isEmpty) return _Empty();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(
              title: 'On the meal plan',
              action: 'View meal plan →',
              onAction: () =>
                  ref.read(selectedTabProvider.notifier).state = 1,
            ),
            SizedBox(
              height: 320,
              child: PageView.builder(
                controller: _controller,
                padEnds: false,
                onPageChanged: (i) => setState(() => _active = i),
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
            _Dots(count: recipes.length, active: _active),
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

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel(title: 'On the meal plan'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: c.surfaceContainer,
              borderRadius: Shapes.tornCorner,
            ),
            child: Text(
              'Star recipes to build your week.',
              style: TextStyle(color: c.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int active;

  const _Dots({required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final isActive = i == active;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: isActive ? 22 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? c.primary : c.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }
}
