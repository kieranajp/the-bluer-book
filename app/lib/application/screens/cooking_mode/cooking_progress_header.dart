import 'package:flutter/material.dart';

import '../../styles/colours.dart';

/// Progress: "Step X of N" + a chunky bar.
class CookingProgressHeader extends StatelessWidget {
  final int current;
  final int total;

  const CookingProgressHeader({
    super.key,
    required this.current,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STEP ${current + 1} OF $total',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : (current + 1) / total,
              minHeight: 8,
              backgroundColor: c.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation<Color>(c.primary),
            ),
          ),
        ],
      ),
    );
  }
}
