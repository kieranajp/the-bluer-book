import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/ingredient.dart';
import '../providers/pantry_providers.dart';
import '../styles/colours.dart';
import 'ingredient_row.dart';
import 'ingredients_summary.dart';

/// Tap-to-check ingredient rows. A checked row means "I have this in my
/// pantry" — tapping persists to the shared pantry via [pantryProvider], so
/// the state survives navigation and shows up in "what can I cook". Squircle
/// checkbox, name, and a monospace quantity pill anchored to the right.
class IngredientsList extends ConsumerWidget {
  final List<Ingredient> ingredients;

  const IngredientsList({super.key, required this.ingredients});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pantry = ref.watch(pantryProvider).value ?? const <String>{};
    final hasComponents = ingredients.any(
      (i) => i.component != null && i.component!.isNotEmpty,
    );
    final checkedCount =
        ingredients.where((i) => pantry.contains(i.detail.name)).length;

    Future<void> toggle(String name) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref.read(pantryProvider.notifier).toggle(name);
      } catch (_) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Couldn't update your pantry"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IngredientsSummary(checked: checkedCount, total: ingredients.length),
          if (hasComponents)
            ..._grouped(pantry, toggle)
          else
            ..._flat(pantry, toggle),
        ],
      ),
    );
  }

  List<Widget> _flat(Set<String> pantry, Future<void> Function(String) toggle) {
    return [
      for (final ingredient in ingredients)
        IngredientRow(
          ingredient: ingredient,
          checked: pantry.contains(ingredient.detail.name),
          onTap: () => toggle(ingredient.detail.name),
        ),
    ];
  }

  List<Widget> _grouped(
      Set<String> pantry, Future<void> Function(String) toggle) {
    final groups = <String, List<Ingredient>>{};
    for (final ingredient in ingredients) {
      final key = ingredient.component ?? '';
      groups.putIfAbsent(key, () => []).add(ingredient);
    }
    final ordered = <String>[];
    if (groups.containsKey('')) ordered.add('');
    for (final k in groups.keys) {
      if (k.isNotEmpty) ordered.add(k);
    }

    return [
      for (final key in ordered) ...[
        if (key.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 4),
            child: Builder(
              builder: (context) => Text(
                'For the $key',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.colours.textPrimary,
                ),
              ),
            ),
          ),
        for (final ingredient in groups[key]!)
          IngredientRow(
            ingredient: ingredient,
            checked: pantry.contains(ingredient.detail.name),
            onTap: () => toggle(ingredient.detail.name),
          ),
      ],
    ];
  }
}
