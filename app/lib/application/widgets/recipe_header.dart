import 'package:flutter/material.dart';
import '../../domain/label.dart';
import '../styles/text_styles.dart';
import '../styles/spacing.dart';

class RecipeHeader extends StatelessWidget {
  final String name;
  final String description;
  final List<Label> labels;

  const RecipeHeader({
    super.key,
    required this.name,
    required this.description,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            name,
            style: TextStyles.pageTitle(context),
          ),
          const SizedBox(height: Spacing.xs),

          // TODO: Source link when added to model

          const SizedBox(height: Spacing.s),

          // Description
          Text(
            description,
            style: TextStyles.bodyText(context),
          ),

          const SizedBox(height: Spacing.m),

          // Tags
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: labels.map((label) {
              return _RecipeTag(
                text: label.name,
                colour: label.colour,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _RecipeTag extends StatelessWidget {
  final String text;
  final String? colour;

  const _RecipeTag({
    required this.text,
    this.colour,
  });

  Color _getLabelColor() {
    if (colour == null) return const Color(0xFF4E6983);

    try {
      if (colour!.startsWith('#')) {
        return Color(int.parse(colour!.substring(1), radix: 16) + 0xFF000000);
      }
      return const Color(0xFF4E6983);
    } catch (e) {
      return const Color(0xFF4E6983);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tagColor = _getLabelColor();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: tagColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tagColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyles.tag(context).copyWith(color: tagColor),
      ),
    );
  }
}
