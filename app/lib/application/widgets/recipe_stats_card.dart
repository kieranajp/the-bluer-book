import 'package:flutter/material.dart';
import '../styles/colours.dart';
import '../styles/shapes.dart';
import '../utils/time_format.dart';

/// Three-stat tonal card: Prep / Cook / Serves. Each icon sits in a different
/// shape — squircle, blob, diamond — to demonstrate the Shape DNA rules.
class RecipeStatsCard extends StatelessWidget {
  final int preparationTime;
  final int cookingTime;
  final int servings;

  const RecipeStatsCard({
    super.key,
    required this.preparationTime,
    required this.cookingTime,
    required this.servings,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 22),
        decoration: BoxDecoration(
          color: c.surfaceContainer,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            Expanded(
              child: _StatCell(
                icon: Icons.schedule,
                value: formatMinutes(preparationTime),
                label: 'PREP',
                background: c.primaryContainer,
                foreground: c.onPrimaryContainer,
                shape: BorderRadius.circular(14), // squircle
              ),
            ),
            _Divider(),
            Expanded(
              child: _StatCell(
                icon: Icons.local_fire_department_rounded,
                value: formatMinutes(cookingTime),
                label: 'COOK',
                background: c.tertiaryContainer,
                foreground: c.onTertiaryContainer,
                shape: Shapes.blob(44), // blob
              ),
            ),
            _Divider(),
            Expanded(
              child: _StatCell(
                icon: Icons.people_alt_outlined,
                value: '$servings',
                label: 'SERVES',
                background: c.secondaryContainer,
                foreground: c.onSecondaryContainer,
                shape: Shapes.diamondish, // diamond-ish
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color background;
  final Color foreground;
  final BorderRadius shape;

  const _StatCell({
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

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: context.colours.outlineVariant.withValues(alpha: 0.55),
    );
  }
}
