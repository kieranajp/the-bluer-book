import 'package:flutter/material.dart';

import '../../styles/colours.dart';
import '../../styles/shapes.dart';

/// The "previous step" button in the cooking-mode bottom controls.
class CookingPrevButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const CookingPrevButton({
    super.key,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colours;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surfaceContainerHigh,
            borderRadius: Shapes.tornCornerSmall,
          ),
          child: Icon(Icons.arrow_back_rounded, color: c.textPrimary, size: 22),
        ),
      ),
    );
  }
}
