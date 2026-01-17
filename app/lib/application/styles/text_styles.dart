import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colours.dart';

/// Text style definitions (theme-aware)
class TextStyles {
  // Headers
  static TextStyle appBarTitle(BuildContext context) => GoogleFonts.workSans(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: context.colours.textPrimary,
      );

  static TextStyle sectionHeading(BuildContext context) => GoogleFonts.workSans(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: context.colours.textPrimary,
      );

  // Body text
  static TextStyle body(BuildContext context) => GoogleFonts.workSans(
        color: context.colours.textPrimary,
      );

  static TextStyle bodySecondary(BuildContext context) => GoogleFonts.workSans(
        color: context.colours.textSecondary,
      );

  // Buttons
  static TextStyle button(BuildContext context) => GoogleFonts.workSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: context.colours.primary,
      );

  // Search
  static TextStyle searchHint(BuildContext context) => GoogleFonts.workSans(
        color: context.colours.textSecondary,
      );

  // Details screen
  static TextStyle pageTitle(BuildContext context) => GoogleFonts.workSans(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: context.colours.textPrimary,
      );

  static TextStyle bodyText(BuildContext context) => GoogleFonts.workSans(
        fontSize: 14,
        color: context.colours.textSecondary,
        height: 1.5,
      );

  static TextStyle tag(BuildContext context) => GoogleFonts.workSans(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      );

  static TextStyle caption(BuildContext context) => GoogleFonts.workSans(
        fontSize: 12,
        color: context.colours.textSecondary,
      );

  static TextStyle statValue(BuildContext context) => GoogleFonts.workSans(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: context.colours.textPrimary,
      );

  static TextStyle buttonText(BuildContext context) => GoogleFonts.workSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      );

  static TextStyle tabActive(BuildContext context) => GoogleFonts.workSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: context.colours.primary,
      );

  static TextStyle tabInactive(BuildContext context) => GoogleFonts.workSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: context.colours.textSecondary,
      );
}
