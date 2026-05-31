import 'package:flutter/material.dart';
import 'colours.dart';
import 'spacing.dart';
import 'text_styles.dart';

/// Reusable box decorations (theme-aware)
class Decorations {
  /// Standard text-field decoration used across the edit forms.
  static InputDecoration input(BuildContext context, String label) =>
      InputDecoration(
        labelText: label,
        labelStyle: TextStyles.caption(context),
        filled: true,
        fillColor: context.colours.background,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: Spacing.s, vertical: Spacing.xs),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colours.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colours.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colours.primary),
        ),
      );

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

  /// Standard card decoration used by recipe list items, meal plan cards, etc.
  static BoxDecoration card(BuildContext context) => BoxDecoration(
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
