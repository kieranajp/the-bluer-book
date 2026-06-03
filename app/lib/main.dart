import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'application/screens/app_shell/app_shell.dart';
import 'application/styles/colours.dart';
import 'application/providers/theme_provider.dart';

void main() {
  runApp(const ProviderScope(child: BluerBook()));
}

class BluerBook extends ConsumerWidget {
  const BluerBook({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'The Bluer Book',
      debugShowCheckedModeBanner: false,

      theme: _buildTheme(Brightness.light, Colours.light),
      darkTheme: _buildTheme(Brightness.dark, Colours.dark),
      themeMode: themeMode,

      home: const AppShell(),
    );
  }
}

ThemeData _buildTheme(Brightness brightness, Colours c) {
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
