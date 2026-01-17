import 'package:flutter/material.dart';
import 'colours.dart';

/// Reusable box decorations (theme-aware)
class Decorations {
  static BoxDecoration searchBar(BuildContext context) => BoxDecoration(
        color: context.colours.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colours.border),
        boxShadow: [
          BoxShadow(
            color: context.colours.shadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      );
}
