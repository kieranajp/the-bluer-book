import 'package:flutter/material.dart';
import '../styles/colours.dart';
import '../styles/text_styles.dart';
import '../styles/spacing.dart';

class RecipeTabBar extends SliverPersistentHeaderDelegate {
  final int selectedTab;
  final Function(int) onTabSelected;

  RecipeTabBar({
    required this.selectedTab,
    required this.onTabSelected,
  });

  @override
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: context.colours.background,
        border: Border(
          bottom: BorderSide(
            color: context.colours.border,
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.m),
        child: Row(
          children: [
            // Ingredients tab
            Expanded(
              child: GestureDetector(
                onTap: () => onTabSelected(0),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: Spacing.m),
                  decoration: BoxDecoration(
                    border: selectedTab == 0
                        ? Border(
                            bottom: BorderSide(
                              color: context.colours.primary,
                              width: 2,
                            ),
                          )
                        : null,
                  ),
                  child: Text(
                    'Ingredients',
                    style: selectedTab == 0
                        ? TextStyles.tabActive(context)
                        : TextStyles.tabInactive(context),
                  ),
                ),
              ),
            ),

            // Instructions tab
            Expanded(
              child: GestureDetector(
                onTap: () => onTabSelected(1),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: Spacing.m),
                  decoration: BoxDecoration(
                    border: selectedTab == 1
                        ? Border(
                            bottom: BorderSide(
                              color: context.colours.primary,
                              width: 2,
                            ),
                          )
                        : null,
                  ),
                  child: Text(
                    'Instructions',
                    style: selectedTab == 1
                        ? TextStyles.tabActive(context)
                        : TextStyles.tabInactive(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant RecipeTabBar oldDelegate) {
    return oldDelegate.selectedTab != selectedTab;
  }
}
