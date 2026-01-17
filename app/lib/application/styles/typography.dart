import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colours.dart';

/// Typography definitions
class Typography {
  // Headers
  static TextStyle get appBarTitle => GoogleFonts.workSans(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colours.textPrimary,
      );

  static TextStyle get sectionHeading => GoogleFonts.workSans(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colours.textPrimary,
      );

  // Body text
  static TextStyle get body => GoogleFonts.workSans(
        color: Colours.textPrimary,
      );

  static TextStyle get bodySecondary => GoogleFonts.workSans(
        color: Colours.textSecondary,
      );

  // Buttons
  static TextStyle get button => GoogleFonts.workSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colours.primary,
      );

  // Search
  static TextStyle get searchHint => GoogleFonts.workSans(
        color: Colours.textSecondary,
      );
}
