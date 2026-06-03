import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../providers/edit_recipe_provider.dart';
import '../../styles/text_styles.dart';
import '../../styles/spacing.dart';
import 'edit_recipe_form_field.dart';

class EditRecipeDetailsSection extends StatelessWidget {
  final EditRecipeState editState;
  final EditRecipeNotifier notifier;

  const EditRecipeDetailsSection({
    super.key,
    required this.editState,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Details', style: TextStyles.sectionHeading(context)),
        const SizedBox(height: Spacing.s),
        Row(
          children: [
            Expanded(
              child: EditRecipeFormField(
                label: 'Prep (min)',
                value: editState.preparationTime.toString(),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) =>
                    notifier.updatePrepTime(int.tryParse(v) ?? 0),
              ),
            ),
            const SizedBox(width: Spacing.s),
            Expanded(
              child: EditRecipeFormField(
                label: 'Cook (min)',
                value: editState.cookingTime.toString(),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) =>
                    notifier.updateCookTime(int.tryParse(v) ?? 0),
              ),
            ),
            const SizedBox(width: Spacing.s),
            Expanded(
              child: EditRecipeFormField(
                label: 'Servings',
                value: editState.servings.toString(),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) =>
                    notifier.updateServings(int.tryParse(v) ?? 1),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
