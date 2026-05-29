import 'package:flutter/material.dart';

/// Garden Plot palette — denim × sage × honey amber.
/// Seeds: #3E5C7E (denim) × #6B8E5A (sage) × #C8923B (honey amber)
///
/// Fields map to M3 ColorScheme roles. The legacy aliases (background, surface,
/// primary, textPrimary, textSecondary, border, shadow) are preserved so older
/// screens keep working while M3-aware screens use the full ladder.
@immutable
class Colours extends ThemeExtension<Colours> {
  // Legacy semantic aliases (kept for existing widgets)
  final Color background;
  final Color surface;
  final Color primary;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color shadow;

  // M3 primary
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;

  // M3 secondary (sage)
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;

  // M3 tertiary (honey amber)
  final Color tertiary;
  final Color onTertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;

  // Surface ladder
  final Color surfaceDim;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color surfaceVariant;

  // Outlines
  final Color outline;
  final Color outlineVariant;

  const Colours({
    required this.background,
    required this.surface,
    required this.primary,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.shadow,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.onTertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.surfaceDim,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.surfaceVariant,
    required this.outline,
    required this.outlineVariant,
  });

  // ── Light ──────────────────────────────────────────────────────────
  // Surfaces carry a very faint denim tint — same hue family as primary,
  // near-zero chroma. Keeps "The Bluer Book" feeling blue without the green
  // sage secondary dominating the room.
  static const light = Colours(
    background: Color(0xFFF5F8FC),
    surface: Color(0xFFEAEFF5), // alias of surfaceContainer for legacy widgets
    primary: Color(0xFF3E5C7E),
    textPrimary: Color(0xFF141A24),
    textSecondary: Color(0xFF3F4854),
    border: Color(0xFFC0C5CE),
    shadow: Color(0x14000000),

    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFCDDBE9),
    onPrimaryContainer: Color(0xFF091828),

    secondary: Color(0xFF6B8E5A),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFD5E5C8),
    onSecondaryContainer: Color(0xFF142712),

    tertiary: Color(0xFFA07626),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFF3DCB0),
    onTertiaryContainer: Color(0xFF2B1C04),

    surfaceDim: Color(0xFFE7ECF4),
    surfaceContainerLow: Color(0xFFEFF3F8),
    surfaceContainer: Color(0xFFEAEFF5),
    surfaceContainerHigh: Color(0xFFE4EAF1),
    surfaceContainerHighest: Color(0xFFDEE5ED),
    surfaceVariant: Color(0xFFDDE3EB),

    outline: Color(0xFF6E7682),
    outlineVariant: Color(0xFFC0C5CE),
  );

  // ── Dark ───────────────────────────────────────────────────────────
  // Surfaces are midnight-denim — same hue family as primary, chroma high
  // enough to register as actually blue rather than cool gray.
  static const dark = Colours(
    background: Color(0xFF0F1726),
    surface: Color(0xFF1A2438), // alias of surfaceContainer
    primary: Color(0xFFA8BDD2),
    textPrimary: Color(0xFFE2E4E8),
    textSecondary: Color(0xFFA6AAB0),
    border: Color(0xFF3F485A),
    shadow: Color(0x33000000),

    onPrimary: Color(0xFF102134),
    primaryContainer: Color(0xFF2A3F58),
    onPrimaryContainer: Color(0xFFCDDBE9),

    secondary: Color(0xFFB7D2A6),
    onSecondary: Color(0xFF1A2C13),
    secondaryContainer: Color(0xFF33472A),
    onSecondaryContainer: Color(0xFFD5E5C8),

    tertiary: Color(0xFFE9C384),
    onTertiary: Color(0xFF382608),
    tertiaryContainer: Color(0xFF54401B),
    onTertiaryContainer: Color(0xFFF3DCB0),

    surfaceDim: Color(0xFF0B1220),
    surfaceContainerLow: Color(0xFF161F30),
    surfaceContainer: Color(0xFF1A2438),
    surfaceContainerHigh: Color(0xFF212C43),
    surfaceContainerHighest: Color(0xFF29354E),
    surfaceVariant: Color(0xFF3F485A),

    outline: Color(0xFF8993A4),
    outlineVariant: Color(0xFF3F485A),
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
    Color? onPrimary,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? secondary,
    Color? onSecondary,
    Color? secondaryContainer,
    Color? onSecondaryContainer,
    Color? tertiary,
    Color? onTertiary,
    Color? tertiaryContainer,
    Color? onTertiaryContainer,
    Color? surfaceDim,
    Color? surfaceContainerLow,
    Color? surfaceContainer,
    Color? surfaceContainerHigh,
    Color? surfaceContainerHighest,
    Color? surfaceVariant,
    Color? outline,
    Color? outlineVariant,
  }) {
    return Colours(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      primary: primary ?? this.primary,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      shadow: shadow ?? this.shadow,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      secondary: secondary ?? this.secondary,
      onSecondary: onSecondary ?? this.onSecondary,
      secondaryContainer: secondaryContainer ?? this.secondaryContainer,
      onSecondaryContainer: onSecondaryContainer ?? this.onSecondaryContainer,
      tertiary: tertiary ?? this.tertiary,
      onTertiary: onTertiary ?? this.onTertiary,
      tertiaryContainer: tertiaryContainer ?? this.tertiaryContainer,
      onTertiaryContainer: onTertiaryContainer ?? this.onTertiaryContainer,
      surfaceDim: surfaceDim ?? this.surfaceDim,
      surfaceContainerLow: surfaceContainerLow ?? this.surfaceContainerLow,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest ?? this.surfaceContainerHighest,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      outline: outline ?? this.outline,
      outlineVariant: outlineVariant ?? this.outlineVariant,
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
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primaryContainer: Color.lerp(primaryContainer, other.primaryContainer, t)!,
      onPrimaryContainer: Color.lerp(onPrimaryContainer, other.onPrimaryContainer, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      onSecondary: Color.lerp(onSecondary, other.onSecondary, t)!,
      secondaryContainer: Color.lerp(secondaryContainer, other.secondaryContainer, t)!,
      onSecondaryContainer: Color.lerp(onSecondaryContainer, other.onSecondaryContainer, t)!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
      onTertiary: Color.lerp(onTertiary, other.onTertiary, t)!,
      tertiaryContainer: Color.lerp(tertiaryContainer, other.tertiaryContainer, t)!,
      onTertiaryContainer: Color.lerp(onTertiaryContainer, other.onTertiaryContainer, t)!,
      surfaceDim: Color.lerp(surfaceDim, other.surfaceDim, t)!,
      surfaceContainerLow: Color.lerp(surfaceContainerLow, other.surfaceContainerLow, t)!,
      surfaceContainer: Color.lerp(surfaceContainer, other.surfaceContainer, t)!,
      surfaceContainerHigh: Color.lerp(surfaceContainerHigh, other.surfaceContainerHigh, t)!,
      surfaceContainerHighest: Color.lerp(surfaceContainerHighest, other.surfaceContainerHighest, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineVariant: Color.lerp(outlineVariant, other.outlineVariant, t)!,
    );
  }
}

// Helper extension to easily access colors from context
extension ColoursExtension on BuildContext {
  Colours get colours => Theme.of(this).extension<Colours>()!;
}
