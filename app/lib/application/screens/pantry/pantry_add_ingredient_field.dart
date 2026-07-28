import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/ingredient.dart';
import '../../providers/pantry_providers.dart';
import '../../styles/colours.dart';
import '../../styles/spacing.dart';

/// Autocomplete field at the top of the [PantryScreen] for adding ingredients
/// you have at home, drawn from the known ingredient names.
class PantryAddIngredientField extends ConsumerWidget {
  final List<IngredientDetail> ingredients;

  const PantryAddIngredientField({super.key, required this.ingredients});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.m, 0, Spacing.m, Spacing.s),
      child: Autocomplete<IngredientDetail>(
        displayStringForOption: (option) => option.name,
        optionsBuilder: (value) {
          final query = value.text.trim().toLowerCase();
          if (query.isEmpty) return const Iterable<IngredientDetail>.empty();
          final pantry = ref.read(pantryProvider).value ?? const <String>{};
          // The two halves of this test used to disagree: the filter lowercased
          // but the exclusion compared display names, so an ingredient already
          // in the pantry under different casing kept being suggested.
          return ingredients
              .where((i) =>
                  i.name.toLowerCase().contains(query) &&
                  !pantry.contains(i.key))
              .take(8);
        },
        onSelected: (selection) {
          ref
              .read(pantryProvider.notifier)
              .add(selection.name, key: selection.key);
        },
        fieldViewBuilder:
            (context, controller, focusNode, onFieldSubmitted) {
          final c = context.colours;
          return TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              hintText: 'Add an ingredient you have…',
              prefixIcon: const Icon(Icons.add_rounded),
              filled: true,
              fillColor: c.surfaceContainer,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (value) {
              final query = ingredientKey(value);
              for (final ingredient in ingredients) {
                if (ingredient.key == query) {
                  ref
                      .read(pantryProvider.notifier)
                      .add(ingredient.name, key: ingredient.key);
                  controller.clear();
                  return;
                }
              }
            },
          );
        },
      ),
    );
  }
}
