import 'package:flutter/material.dart';
import '../styles/colours.dart';

/// Header row for [IngredientsList]: how many ingredients are already in the
/// pantry, plus a hint that tapping stocks the pantry.
class IngredientsSummary extends StatelessWidget {
  final int checked;
  final int total;

  const IngredientsSummary({
    super.key,
    required this.checked,
    required this.total,
  });

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
