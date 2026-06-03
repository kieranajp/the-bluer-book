import 'package:flutter/material.dart';
import '../styles/colours.dart';
import '../utils/cookability.dart';

/// Small pill showing how cookable a recipe is from the current pantry:
/// "Ready" when you have every ingredient, otherwise "Missing N".
class RecipeCookBadge extends StatelessWidget {
  final Cookability cook;

  const RecipeCookBadge({super.key, required this.cook});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    final ready = cook.ready;
    final bg = ready ? c.primaryContainer : c.surfaceContainer;
    final fg = ready ? c.primary : c.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ready ? Icons.check_circle_rounded : Icons.shopping_basket_outlined,
            size: 11,
            color: fg,
          ),
          const SizedBox(width: 3),
          Text(
            ready ? 'Ready' : 'Missing ${cook.missing}',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
