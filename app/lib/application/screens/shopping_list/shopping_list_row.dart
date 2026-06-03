import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/shopping_list_item.dart';
import '../../providers/pantry_providers.dart';
import '../../styles/colours.dart';
import '../../styles/shapes.dart';

/// One buyable item in the [ShoppingListScreen]. Tapping checks it off: a
/// meal-plan ingredient lands in the pantry (so it drops off the list), a
/// custom item is just removed.
class ShoppingListRow extends ConsumerWidget {
  final ShoppingListItem item;

  const ShoppingListRow({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colours;

    Future<void> buy() async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref.read(shoppingListProvider.notifier).check(item);
        messenger.showSnackBar(
          SnackBar(
            content: Text(item.isCustom
                ? 'Removed "${item.name}"'
                : 'Added "${item.name}" to your pantry'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (_) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Couldn't update your shopping list"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    return InkWell(
      onTap: buy,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: Shapes.squircle(10),
                border: Border.all(color: c.outlineVariant, width: 2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                item.name,
                style: TextStyle(fontSize: 14.5, color: c.textPrimary),
              ),
            ),
            // Custom (non-recipe) extras get a small marker so it's clear they
            // aren't part of the meal plan.
            if (item.isCustom)
              Icon(Icons.push_pin_outlined, size: 16, color: c.textSecondary)
            else
              Icon(Icons.add_rounded, size: 18, color: c.textSecondary),
          ],
        ),
      ),
    );
  }
}
