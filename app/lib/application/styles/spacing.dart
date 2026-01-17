import 'package:flutter/material.dart';

/// Spacing constants for consistent layout
class Spacing {
  // Base values
  static const xs = 8.0;
  static const s = 12.0;
  static const m = 16.0;
  static const l = 24.0;
  static const xl = 32.0;

  // Specific component sizes
  static const searchBarHeight = 48.0;
  static const mealPlanHeight = 240.0;
  static const bottomSpacer = 96.0;

  // EdgeInsets presets
  static const horizontal = EdgeInsets.symmetric(horizontal: m);
  static const vertical = EdgeInsets.symmetric(vertical: xs);
  static const all = EdgeInsets.all(m);

  static const searchIconPadding = EdgeInsets.symmetric(horizontal: m);
  static const listItemPadding = EdgeInsets.symmetric(
    horizontal: m,
    vertical: xs,
  );
}
