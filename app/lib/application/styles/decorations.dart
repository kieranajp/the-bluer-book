import 'package:flutter/material.dart';
import 'colours.dart';

/// Reusable box decorations
class Decorations {
  static BoxDecoration get searchBar => BoxDecoration(
        color: Colours.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colours.border),
        boxShadow: [
          BoxShadow(
            color: Colours.shadowLight,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      );
}
