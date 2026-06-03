import 'package:flutter/material.dart';
import '../styles/colours.dart';

/// One stat in the [RecipeStatsCard] — a tonal icon plate over a value and a
/// small caption. The icon plate's [shape] varies per stat (squircle / blob /
/// diamond) to show off the Shape DNA rules.
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
    final c = context.colours;
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
