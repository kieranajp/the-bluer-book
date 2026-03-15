import 'package:flutter/material.dart';
import '../../domain/label.dart';
import '../styles/text_styles.dart';
import '../styles/spacing.dart';
import 'label_tag.dart';

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
            spacing: Spacing.xs,
            runSpacing: Spacing.xs,
            children: labels.map((label) => LabelTagFull(label: label)).toList(),
          ),
        ],
      ),
    );
  }
}
