import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colours.dart';

/// Builds the app's [ThemeData] for a given [brightness] and [Colours] palette.
///
/// Lives here (rather than inline in `main.dart`) so tests — golden tests in
/// particular — render widgets under the exact theme that ships, with no
/// hand-maintained copy to drift out of sync.
ThemeData buildAppTheme(Brightness brightness, Colours c) {
  // Explicit ColorScheme — no fromSeed. Tonal values match the Garden Plot
  // palette so what's on the design canvas is what ships.
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.primary,
    onPrimary: c.onPrimary,
    primaryContainer: c.primaryContainer,
    onPrimaryContainer: c.onPrimaryContainer,
    secondary: c.secondary,
    onSecondary: c.onSecondary,
    secondaryContainer: c.secondaryContainer,
    onSecondaryContainer: c.onSecondaryContainer,
    tertiary: c.tertiary,
    onTertiary: c.onTertiary,
    tertiaryContainer: c.tertiaryContainer,
    onTertiaryContainer: c.onTertiaryContainer,
    error: brightness == Brightness.light
        ? const Color(0xFFBA1A1A)
        : const Color(0xFFFFB4AB),
    onError: brightness == Brightness.light
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF690005),
    errorContainer: brightness == Brightness.light
        ? const Color(0xFFFFDAD6)
        : const Color(0xFF93000A),
    onErrorContainer: brightness == Brightness.light
        ? const Color(0xFF410002)
        : const Color(0xFFFFDAD6),
    surface: c.background,
    onSurface: c.textPrimary,
    surfaceContainerLowest: c.background,
    surfaceContainerLow: c.surfaceContainerLow,
    surfaceContainer: c.surfaceContainer,
    surfaceContainerHigh: c.surfaceContainerHigh,
    surfaceContainerHighest: c.surfaceContainerHighest,
    surfaceDim: c.surfaceDim,
    onSurfaceVariant: c.textSecondary,
    outline: c.outline,
    outlineVariant: c.outlineVariant,
    shadow: c.shadow,
    inverseSurface: brightness == Brightness.light
        ? c.textPrimary
        : c.background,
    onInverseSurface: brightness == Brightness.light
        ? c.background
        : c.textPrimary,
    inversePrimary: brightness == Brightness.light
        ? const Color(0xFFA8BDD2)
        : const Color(0xFF3E5C7E),
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    textTheme: GoogleFonts.workSansTextTheme(
      brightness == Brightness.light
          ? ThemeData.light().textTheme
          : ThemeData.dark().textTheme,
    ),
    useMaterial3: true,
    extensions: [c],
  );
}
