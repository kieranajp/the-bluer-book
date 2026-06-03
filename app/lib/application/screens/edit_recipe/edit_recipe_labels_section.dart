import 'package:flutter/material.dart';
import '../../providers/edit_recipe_provider.dart';
import '../../widgets/label_edit_chip.dart';
import '../../styles/colours.dart';
import '../../styles/text_styles.dart';
import '../../styles/spacing.dart';

class EditRecipeLabelsSection extends StatelessWidget {
  final EditRecipeState editState;
  final EditRecipeNotifier notifier;
  final VoidCallback onAddLabel;

  const EditRecipeLabelsSection({
    super.key,
    required this.editState,
    required this.notifier,
    required this.onAddLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Labels', style: TextStyles.sectionHeading(context)),
            const Spacer(),
            IconButton(
              onPressed: onAddLabel,
              icon: Icon(Icons.add_circle_outline,
                  color: context.colours.primary),
            ),
          ],
        ),
        const SizedBox(height: Spacing.xs),
        Wrap(
          children: List.generate(editState.labels.length, (i) {
            return LabelEditChip(
              label: editState.labels[i],
              onDelete: () => notifier.removeLabel(i),
            );
          }),
        ),
      ],
    );
  }
}
