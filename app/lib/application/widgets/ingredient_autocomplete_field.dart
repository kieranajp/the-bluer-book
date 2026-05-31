import 'package:flutter/material.dart';

import '../../domain/ingredient.dart';
import '../providers/edit_recipe_provider.dart';
import '../styles/decorations.dart';
import '../styles/text_styles.dart';
import 'autocomplete_options_dropdown.dart';

/// Name field for an ingredient being edited, with autocomplete over the
/// known ingredient list. Reports edits by cloning [ingredient] via [onChanged].
class IngredientAutocompleteField extends StatelessWidget {
  final EditableIngredient ingredient;
  final List<IngredientDetail> available;
  final ValueChanged<EditableIngredient> onChanged;

  const IngredientAutocompleteField({
    super.key,
    required this.ingredient,
    required this.available,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<IngredientDetail>(
      initialValue: TextEditingValue(text: ingredient.name),
      displayStringForOption: (ing) => ing.name,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.toLowerCase().trim();
        if (query.isEmpty) {
          return available;
        }
        return available
            .where((ing) => ing.name.toLowerCase().contains(query));
      },
      onSelected: (ing) {
        onChanged(ingredient.clone()..name = ing.name);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: Decorations.input(context, 'Name'),
          style: TextStyles.body(context),
          onChanged: (v) => onChanged(ingredient.clone()..name = v),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return AutocompleteOptionsDropdown<IngredientDetail>(
          options: options,
          onSelected: onSelected,
          titleBuilder: (ing) => ing.name,
        );
      },
    );
  }
}
