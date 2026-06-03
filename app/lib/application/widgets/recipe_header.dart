import 'package:flutter/material.dart';
import '../../domain/label.dart';
import '../styles/colours.dart';
import '../styles/shapes.dart';
import '../styles/text_styles.dart';
import 'recipe_label_chip.dart';
import 'recipe_source_link.dart';

/// Title block for the recipe details screen — sits in a top-radius "sheet"
/// that overlaps the hero by 28px. Chips → serif italic title → description →
/// source link.
class RecipeHeader extends StatelessWidget {
  final String name;
  final String description;
  final List<Label> labels;
  final String? url;

  const RecipeHeader({
    super.key,
    required this.name,
    required this.description,
    required this.labels,
    this.url,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Transform.translate(
      offset: const Offset(0, -28),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: Shapes.sheetTop,
        ),
        padding: const EdgeInsets.fromLTRB(22, 36, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (labels.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children:
                    labels.take(3).map((l) => RecipeLabelChip(label: l)).toList(),
              ),
            if (labels.isNotEmpty) const SizedBox(height: 16),
            Text(name, style: TextStyles.recipeTitle(context)),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.55,
                  color: c.textSecondary,
                ),
              ),
            ],
            if (url != null && url!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              RecipeSourceLink(url: url!.trim()),
            ],
          ],
        ),
      ),
    );
  }
}
