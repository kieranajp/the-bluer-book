// Example: a clean leaf widget — one class, its own file, design-system styling.
//
// This is illustrative (it lives in the skill, not in app/lib). It mirrors the
// real `recipe_stat_cell.dart`. Note what it does NOT do: no second widget class,
// no `Widget _buildX()` helper, no hardcoded colours or pixel sizes pulled from
// nowhere.

import 'package:flutter/material.dart';
import '../styles/colours.dart'; // in real code: '../styles/colours.dart'

/// One stat in a stats card — a tonal icon plate over a value and a caption.
/// Inputs are explicit; the widget is "dumb" and const-constructible.
class RecipeStatCell extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color background;
  final Color foreground;
  final BorderRadius shape;

  const RecipeStatCell({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.background,
    required this.foreground,
    required this.shape,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colours; // ← colours from the ThemeExtension, never hardcoded
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: background, borderRadius: shape),
          child: Icon(icon, size: 20, color: foreground),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.4,
            color: c.textSecondary,
          ),
        ),
      ],
    );
  }
}
