import 'package:flutter/material.dart';

import '../../domain/recipe.dart';
import '../screens/cooking_mode_screen.dart';
import '../styles/colours.dart';
import '../styles/shapes.dart';

/// "Start cooking" CTA on the recipe details screen. Opens the step-by-step
/// cooking mode. Sage (secondary) tone so it reads as a distinct action from
/// the primary "Add to meal plan" button beneath it.
class CookingModeButton extends StatelessWidget {
  final Recipe recipe;

  const CookingModeButton({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CookingModeScreen(recipe: recipe),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          decoration: BoxDecoration(
            color: c.secondary,
            borderRadius: Shapes.tornCornerSmall,
            boxShadow: [
              BoxShadow(
                color: c.secondary.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.onSecondary.withValues(alpha: 0.2),
                  borderRadius: Shapes.blob(40),
                ),
                child: Icon(
                  Icons.soup_kitchen_outlined,
                  size: 20,
                  color: c.onSecondary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Start cooking',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: c.onSecondary,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 22, color: c.onSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
