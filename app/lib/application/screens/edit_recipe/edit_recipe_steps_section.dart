import 'package:flutter/material.dart';
import '../../providers/edit_recipe_provider.dart';
import '../../widgets/step_edit_card.dart';
import '../../styles/colours.dart';
import '../../styles/text_styles.dart';
import '../../styles/spacing.dart';

class EditRecipeStepsSection extends StatelessWidget {
  final EditRecipeState editState;
  final EditRecipeNotifier notifier;

  const EditRecipeStepsSection({
    super.key,
    required this.editState,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Steps', style: TextStyles.sectionHeading(context)),
            const Spacer(),
            IconButton(
              onPressed: notifier.addStep,
              icon: Icon(Icons.add_circle_outline,
                  color: context.colours.primary),
            ),
          ],
        ),
        const SizedBox(height: Spacing.xs),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: editState.steps.length,
          onReorderItem: notifier.reorderSteps,
          buildDefaultDragHandles: false,
          proxyDecorator: (child, index, animation) => Material(
            color: Colors.transparent,
            child: child,
          ),
          itemBuilder: (context, i) {
            return StepEditCard(
              key: ValueKey(editState.steps[i].id),
              index: i,
              step: editState.steps[i],
              onChanged: (updated) => notifier.updateStep(i, updated),
              onDelete: () => notifier.removeStep(i),
            );
          },
        ),
      ],
    );
  }
}
