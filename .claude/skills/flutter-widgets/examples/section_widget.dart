// Example: a screen "section" widget — the unit a screen orchestrates.
//
// Illustrative (mirrors edit_recipe/edit_recipe_basic_info_section.dart). A
// section takes the screen's state + notifier (or plain callbacks) and renders;
// it does NOT own save/validation logic — that lives in the notifier. The screen
// composes a column of these, so its own build() reads like a table of contents.

import 'package:flutter/material.dart';
import '../providers/edit_recipe_provider.dart'; // EditRecipeState, EditRecipeNotifier
import '../styles/text_styles.dart';
import '../styles/spacing.dart';
import 'edit_recipe_form_field.dart'; // a sibling widget in the same screen folder

/// "Basic info" block of the edit-recipe screen: name / description / source URL.
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
          onChanged: notifier.updateName, // logic is the notifier's job
        ),
        const SizedBox(height: Spacing.s),
        EditRecipeFormField(
          label: 'Description',
          value: editState.description,
          onChanged: notifier.updateDescription,
          maxLines: 3,
        ),
      ],
    );
  }
}

// The screen that owns this section just composes sections — it doesn't build
// fields itself:
//
//   children: [
//     EditRecipePhotoSection(editState: s, notifier: n),
//     EditRecipeBasicInfoSection(editState: s, notifier: n),
//     EditRecipeDetailsSection(editState: s, notifier: n),
//     ...
//   ]
