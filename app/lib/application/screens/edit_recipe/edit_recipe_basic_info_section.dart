import 'package:flutter/material.dart';
import '../../providers/edit_recipe_provider.dart';
import '../../styles/text_styles.dart';
import '../../styles/spacing.dart';
import 'edit_recipe_form_field.dart';

class EditRecipeBasicInfoSection extends StatelessWidget {
  final EditRecipeState editState;
  final EditRecipeNotifier notifier;

  const EditRecipeBasicInfoSection({
    super.key,
    required this.editState,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Basic Info', style: TextStyles.sectionHeading(context)),
        const SizedBox(height: Spacing.s),
        EditRecipeFormField(
          label: 'Recipe Name',
          value: editState.name,
          onChanged: notifier.updateName,
        ),
        const SizedBox(height: Spacing.s),
        EditRecipeFormField(
          label: 'Description',
          value: editState.description,
          onChanged: notifier.updateDescription,
          maxLines: 3,
        ),
        const SizedBox(height: Spacing.s),
        EditRecipeFormField(
          label: 'Source URL',
          value: editState.url,
          onChanged: notifier.updateUrl,
          keyboardType: TextInputType.url,
        ),
      ],
    );
  }
}
