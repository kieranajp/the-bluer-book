import 'package:flutter/material.dart';
import '../styles/colours.dart';

/// Thin vertical rule separating the cells in the [RecipeStatsCard].
class RecipeStatDivider extends StatelessWidget {
  const RecipeStatDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: context.colours.outlineVariant.withValues(alpha: 0.55),
    );
  }
}
