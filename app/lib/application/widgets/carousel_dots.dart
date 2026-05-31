import 'package:flutter/material.dart';

import '../styles/colours.dart';

/// Page-position dots for the meal-plan carousel; the active dot stretches.
class CarouselDots extends StatelessWidget {
  final int count;
  final int active;

  const CarouselDots({super.key, required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final isActive = i == active;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: isActive ? 22 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? c.primary : c.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }
}
