import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'application/screens/recipe_list_screen.dart';

void main() {
  runApp(const ProviderScope(child: BluerBook()));
}

class BluerBook extends StatelessWidget {
  const BluerBook({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Bluer Book',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4E6983),
          primary: const Color(0xFF4E6983),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F7F7),
        textTheme: GoogleFonts.workSansTextTheme(),
        useMaterial3: true,
      ),
      home: const RecipeListScreen(),
    );
  }
}
