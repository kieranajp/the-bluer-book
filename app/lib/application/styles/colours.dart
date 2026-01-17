import 'package:flutter/material.dart';

/// App color palette with light and dark mode support
@immutable
class Colours extends ThemeExtension<Colours> {
  final Color background;
  final Color surface;
  final Color primary;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color shadow;

  const Colours({
    required this.background,
    required this.surface,
    required this.primary,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.shadow,
  });

  // Light theme colors
  static const light = Colours(
    background: Color(0xFFF6F7F7),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFF4E6983),
    textPrimary: Color(0xFF121416),
    textSecondary: Color(0xFF67737E),
    border: Color(0xFFF0F0F0),
    shadow: Color(0x0D000000), // black with 5% opacity
  );

  // Dark theme colors (from design specs)
  static const dark = Colours(
    background: Color(0xFF16191C),
    surface: Color(0xFF1F2937), // gray-800
    primary: Color(0xFF4E6983),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF9CA3AF), // gray-400
    border: Color(0xFF374151), // gray-700
    shadow: Color(0x1A000000), // slightly more visible in dark mode
  );

  @override
  Colours copyWith({
    Color? background,
    Color? surface,
    Color? primary,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? shadow,
  }) {
    return Colours(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      primary: primary ?? this.primary,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  Colours lerp(ThemeExtension<Colours>? other, double t) {
    if (other is! Colours) return this;
    return Colours(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

// Helper extension to easily access colors from context
extension ColoursExtension on BuildContext {
  Colours get colours => Theme.of(this).extension<Colours>()!;
}
