import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/recipe_providers.dart';
import 'meal_plan_carousel_body.dart';

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
              child: MealPlanCarouselBody(
                controller: _controller,
                active: _active,
                onPageChanged: (i) => setState(() => _active = i),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
