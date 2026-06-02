import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/ingredient.dart';
import '../providers/pantry_providers.dart';
import '../styles/colours.dart';
import '../styles/shapes.dart';

/// Tap-to-check ingredient rows. A checked row means "I have this in my
/// pantry" — tapping persists to the shared pantry via [pantryProvider], so
/// the state survives navigation and shows up in "what can I cook". Squircle
/// checkbox, name, and a monospace quantity pill anchored to the right.
class IngredientsList extends ConsumerWidget {
  final List<Ingredient> ingredients;

  const IngredientsList({super.key, required this.ingredients});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pantry = ref.watch(pantryProvider).valueOrNull ?? const <String>{};
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
          _Summary(checked: checkedCount, total: ingredients.length),
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
        _IngredientRow(
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
          _IngredientRow(
            ingredient: ingredient,
            checked: pantry.contains(ingredient.detail.name),
            onTap: () => toggle(ingredient.detail.name),
          ),
      ],
    ];
  }
}

class _Summary extends StatelessWidget {
  final int checked;
  final int total;

  const _Summary({required this.checked, required this.total});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$checked of $total in your pantry',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: c.textSecondary,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: c.primaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'tap to stock pantry',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: c.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  final Ingredient ingredient;
  final bool checked;
  final VoidCallback onTap;

  const _IngredientRow({
    required this.ingredient,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: checked ? c.secondary : Colors.transparent,
                borderRadius: Shapes.squircle(10),
                border: checked
                    ? null
                    : Border.all(color: c.outlineVariant, width: 2),
              ),
              child: checked
                  ? Icon(Icons.check_rounded, size: 16, color: c.onSecondary)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _name(ingredient),
                style: TextStyle(
                  fontSize: 14.5,
                  color: checked ? c.textSecondary : c.textPrimary,
                  decoration:
                      checked ? TextDecoration.lineThrough : TextDecoration.none,
                  decorationColor: c.outlineVariant,
                ),
              ),
            ),
            if (_qty(ingredient).isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: c.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _qty(ingredient),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: c.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _qty(Ingredient i) {
    final buf = StringBuffer();
    if (i.quantity > 0) {
      if (i.quantity == i.quantity.toInt()) {
        buf.write(i.quantity.toInt());
      } else {
        buf.write(i.quantity);
      }
    }
    final unit = i.unit?.abbreviation?.isNotEmpty == true
        ? i.unit!.abbreviation!
        : (i.unit?.name.isNotEmpty == true ? i.unit!.name : null);
    if (unit != null) {
      if (buf.isNotEmpty) buf.write(' ');
      buf.write(unit);
    }
    return buf.toString();
  }

  String _name(Ingredient i) {
    final name = i.detail.name;
    if (i.preparation != null && i.preparation!.isNotEmpty) {
      return '$name, ${i.preparation}';
    }
    return name;
  }
}
