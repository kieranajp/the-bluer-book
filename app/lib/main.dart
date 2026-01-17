import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'application/screens/recipe_list_screen.dart';
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

      // Light theme
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4E6983),
          primary: const Color(0xFF4E6983),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F7F7),
        textTheme: GoogleFonts.workSansTextTheme(),
        useMaterial3: true,
        extensions: const [Colours.light],
      ),

      // Dark theme
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4E6983),
          primary: const Color(0xFF4E6983),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF16191C),
        textTheme: GoogleFonts.workSansTextTheme(),
        useMaterial3: true,
        extensions: const [Colours.dark],
      ),

      // Theme mode controlled by provider (System/Light/Dark)
      themeMode: themeMode,

      home: const RecipeListScreen(),
    );
  }
}
