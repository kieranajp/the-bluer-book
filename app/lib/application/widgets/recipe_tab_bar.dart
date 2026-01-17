import 'package:flutter/material.dart';
import '../styles/colours.dart';
import '../styles/text_styles.dart';
import '../styles/spacing.dart';

class RecipeTabBar extends SliverPersistentHeaderDelegate {
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
            // Ingredients tab (active)
            Expanded(
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: Spacing.m),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: context.colours.primary,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  'Ingredients',
                  style: TextStyles.tabActive(context),
                ),
              ),
            ),

            // Instructions tab (inactive, for future)
            Expanded(
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: Spacing.m),
                child: Text(
                  'Instructions',
                  style: TextStyles.tabInactive(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}
