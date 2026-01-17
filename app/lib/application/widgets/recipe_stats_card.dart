import 'package:flutter/material.dart';
import '../styles/colours.dart';
import '../styles/text_styles.dart';
import '../styles/spacing.dart';

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.m),
      child: Container(
        decoration: BoxDecoration(
          color: context.colours.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colours.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(Spacing.m),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              icon: Icons.schedule,
              label: 'Prep',
              value: '${preparationTime}m',
            ),
            _StatDivider(),
            _StatItem(
              icon: Icons.timer,
              label: 'Cook',
              value: '${cookingTime}m',
            ),
            _StatDivider(),
            _StatItem(
              icon: Icons.people,
              label: 'Servings',
              value: '$servings',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 24, color: context.colours.primary),
        const SizedBox(height: 4),
        Text(label, style: TextStyles.caption(context)),
        const SizedBox(height: 2),
        Text(value, style: TextStyles.statValue(context)),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: context.colours.border,
    );
  }
}
