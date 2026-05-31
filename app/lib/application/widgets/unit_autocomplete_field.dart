import 'package:flutter/material.dart';

import '../../domain/ingredient.dart';
import '../providers/edit_recipe_provider.dart';
import '../styles/decorations.dart';
import '../styles/text_styles.dart';
import 'autocomplete_options_dropdown.dart';

/// Unit field for an ingredient being edited, with autocomplete over the known
/// units. Reports edits by cloning [ingredient] via [onChanged].
class UnitAutocompleteField extends StatelessWidget {
  final EditableIngredient ingredient;
  final List<IngredientUnit> available;
  final ValueChanged<EditableIngredient> onChanged;

  const UnitAutocompleteField({
    super.key,
    required this.ingredient,
    required this.available,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<IngredientUnit>(
      initialValue: TextEditingValue(text: ingredient.unitName),
      displayStringForOption: (unit) => unit.name,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.toLowerCase().trim();
        if (query.isEmpty) {
          return available;
        }
        return available
            .where((unit) => unit.name.toLowerCase().contains(query));
      },
      onSelected: (unit) {
        onChanged(ingredient.clone()
          ..unitName = unit.name
          ..unitAbbreviation = unit.abbreviation ?? '');
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: Decorations.input(context, 'Unit (optional)'),
          style: TextStyles.body(context),
          onChanged: (v) => onChanged(ingredient.clone()..unitName = v),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return AutocompleteOptionsDropdown<IngredientUnit>(
          options: options,
          onSelected: onSelected,
          titleBuilder: (unit) => unit.name,
          subtitleBuilder: (unit) =>
              unit.abbreviation != null && unit.abbreviation!.isNotEmpty
                  ? unit.abbreviation
                  : null,
        );
      },
    );
  }
}
