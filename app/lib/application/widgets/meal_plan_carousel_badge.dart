import 'package:flutter/material.dart';
import '../styles/colours.dart';

/// The "PLAN" pill (optionally with a label) overlaid on a
/// [MealPlanCarouselCard]'s image.
class MealPlanCarouselBadge extends StatelessWidget {
  final String? label;

  const MealPlanCarouselBadge({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'PLAN',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          if (label != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: c.tertiaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label!,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: c.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
