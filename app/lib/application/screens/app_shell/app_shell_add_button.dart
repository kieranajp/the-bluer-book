import 'package:flutter/material.dart';
import '../../styles/colours.dart';
import '../edit_recipe/edit_recipe_screen.dart';

/// The central "+" action in the [AppShellNavBar] — opens the new-recipe editor.
class AppShellAddButton extends StatelessWidget {
  const AppShellAddButton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: c.primary,
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        shadowColor: c.primary.withValues(alpha: 0.33),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EditRecipeScreen()),
          ),
          child: Container(
            width: 56,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: c.primary.withValues(alpha: 0.33),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(Icons.add_rounded, size: 24, color: c.onPrimary),
          ),
        ),
      ),
    );
  }
}
