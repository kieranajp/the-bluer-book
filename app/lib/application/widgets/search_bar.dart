import 'package:flutter/material.dart';
import '../styles/colours.dart';
import '../styles/text_styles.dart';
import '../styles/spacing.dart';
import '../styles/decorations.dart';

class RecipeSearchBar extends StatelessWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;

  const RecipeSearchBar({
    super.key,
    this.hintText = 'Search recipes...',
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: Spacing.vertical.copyWith(
        left: Spacing.m,
        right: Spacing.m,
      ),
      child: Container(
        height: Spacing.searchBarHeight,
        decoration: Decorations.searchBar(context),
        child: Row(
          children: [
            Padding(
              padding: Spacing.searchIconPadding,
              child: Icon(
                Icons.search,
                color: context.colours.textSecondary,
                size: 24,
              ),
            ),
            Expanded(
              child: TextField(
                onChanged: onChanged,
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyles.searchHint(context),
                  border: InputBorder.none,
                ),
                style: TextStyles.body(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
