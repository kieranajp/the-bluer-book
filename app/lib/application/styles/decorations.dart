import 'package:flutter/material.dart';
import 'colours.dart';
import 'spacing.dart';
import 'text_styles.dart';

/// Reusable decorations (theme-aware)
class Decorations {
  /// Standard [InputDecoration] for form text fields.
  ///
  /// [borderRadius] defaults to 12 (form fields). Chat input uses 24.
  static InputDecoration textField(
    BuildContext context, {
    String? labelText,
    String? hintText,
    double borderRadius = 12,
    EdgeInsetsGeometry? contentPadding,
  }) {
    final radius = BorderRadius.circular(borderRadius);
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyles.caption(context),
      hintText: hintText,
      hintStyle: TextStyles.caption(context),
      filled: true,
      fillColor: context.colours.background,
      contentPadding: contentPadding ??
          const EdgeInsets.symmetric(horizontal: Spacing.s, vertical: Spacing.xs),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: context.colours.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: context.colours.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: context.colours.primary),
      ),
    );
  }

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
