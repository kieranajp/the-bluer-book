import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/pantry_providers.dart';
import '../../styles/colours.dart';
import '../../styles/shapes.dart';

/// One buyable ingredient in the [ShoppingListScreen]. Tapping checks it off,
/// which adds it to the pantry (so it drops off the list).
class ShoppingListRow extends ConsumerWidget {
  final String ingredient;

  const ShoppingListRow({super.key, required this.ingredient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colours;

    Future<void> buy() async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref.read(shoppingListProvider.notifier).check(ingredient);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Added "$ingredient" to your pantry'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (_) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Couldn't update your pantry"),
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
                ingredient,
                style: TextStyle(fontSize: 14.5, color: c.textPrimary),
              ),
            ),
            Icon(Icons.add_rounded, size: 18, color: c.textSecondary),
          ],
        ),
      ),
    );
  }
}
