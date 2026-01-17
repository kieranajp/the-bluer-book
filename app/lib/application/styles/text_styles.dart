import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colours.dart';

/// Text style definitions
class TextStyles {
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

  // Details screen
  static TextStyle get pageTitle => GoogleFonts.workSans(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colours.textPrimary,
      );

  static TextStyle get bodyText => GoogleFonts.workSans(
        fontSize: 14,
        color: Colours.textSecondary,
        height: 1.5,
      );

  static TextStyle get tag => GoogleFonts.workSans(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      );

  static TextStyle get caption => GoogleFonts.workSans(
        fontSize: 12,
        color: Colours.textSecondary,
      );

  static TextStyle get statValue => GoogleFonts.workSans(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colours.textPrimary,
      );

  static TextStyle get buttonText => GoogleFonts.workSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get tabActive => GoogleFonts.workSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colours.primary,
      );

  static TextStyle get tabInactive => GoogleFonts.workSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colours.textSecondary,
      );
}
