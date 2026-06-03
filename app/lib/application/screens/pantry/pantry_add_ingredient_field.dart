import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/pantry_providers.dart';
import '../../styles/colours.dart';
import '../../styles/spacing.dart';

/// Autocomplete field at the top of the [PantryScreen] for adding ingredients
/// you have at home, drawn from the known ingredient names.
class PantryAddIngredientField extends ConsumerWidget {
  final List<String> allNames;

  const PantryAddIngredientField({super.key, required this.allNames});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.m, 0, Spacing.m, Spacing.s),
      child: Autocomplete<String>(
        optionsBuilder: (value) {
          final query = value.text.trim().toLowerCase();
          if (query.isEmpty) return const Iterable<String>.empty();
          final pantry = ref.read(pantryProvider).valueOrNull ?? const <String>{};
          return allNames
              .where((n) =>
                  n.toLowerCase().contains(query) && !pantry.contains(n))
              .take(8);
        },
        onSelected: (selection) {
          ref.read(pantryProvider.notifier).add(selection);
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
              final query = value.trim().toLowerCase();
              final match = allNames.firstWhere(
                (n) => n.toLowerCase() == query,
                orElse: () => '',
              );
              if (match.isNotEmpty) {
                ref.read(pantryProvider.notifier).add(match);
                controller.clear();
              }
            },
          );
        },
      ),
    );
  }
}
