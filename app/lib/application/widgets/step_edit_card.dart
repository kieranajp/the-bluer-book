import 'package:flutter/material.dart';
import '../providers/edit_recipe_provider.dart';
import '../styles/colours.dart';
import '../styles/decorations.dart';
import '../styles/spacing.dart';
import '../styles/text_styles.dart';

class StepEditCard extends StatelessWidget {
  final int index;
  final EditableStep step;
  final ValueChanged<EditableStep> onChanged;
  final VoidCallback onDelete;

  const StepEditCard({
    super.key,
    required this.index,
    required this.step,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.s),
      padding: const EdgeInsets.all(Spacing.m),
      decoration: Decorations.card(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Numbered circle badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: context.colours.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: context.colours.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: Spacing.s),
          // Description field
          Expanded(
            child: TextFormField(
              initialValue: step.description,
              decoration: Decorations.textField(context, hintText: 'Describe this step...'),
              style: TextStyles.body(context),
              maxLines: null,
              minLines: 2,
              onChanged: (v) => onChanged(step.clone()..description = v),
            ),
          ),
          const SizedBox(width: Spacing.xs),
          // Actions column
          Column(
            children: [
              Icon(Icons.drag_handle,
                  color: context.colours.textSecondary, size: 20),
              const SizedBox(height: Spacing.xs),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline,
                    color: context.colours.textSecondary, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
