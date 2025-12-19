import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors from your Figma file
  static const Color primary500 = Color(0xFF8E70EF);
  static const Color primary700 = Color(0xFF16056B);

  static const Color secondary500 = Color(0xFF9EF0FF);
  static Color secondary300 = Color(0x1A9EF0FF);

  static const Color neutral200 = Color(0xFF656262);
  static const Color neutral100 = Color(0xFFFFFFFF);


  static const Color success = Color(0xFF038A08);
  static const Color warning = Color(0xFFCAB601);
  static const Color error = Color(0xFFFF1515);
  static const Color links = Color(0xFF1976F0);

  // THEME
  static final ThemeData theme = ThemeData(
    // Basic color assignments only — nothing added
    primaryColor: primary500,
    scaffoldBackgroundColor: neutral100,

    textTheme: TextTheme(
      headlineLarge: GoogleFonts.shantellSans(
        fontWeight: FontWeight.w600,
        fontSize: 28,
        letterSpacing: 0.4
      ),
      headlineMedium: GoogleFonts.shantellSans(
        fontWeight: FontWeight.w600,
        fontSize: 24,
      ),
      headlineSmall: GoogleFonts.shantellSans(
        fontWeight: FontWeight.w600,
        fontSize: 20,
      ),
      displayLarge: GoogleFonts.shantellSans(
        fontWeight: FontWeight.w700,
        fontSize: 40,
      ),
      displayMedium: GoogleFonts.shantellSans(
        fontWeight: FontWeight.w700,
        fontSize: 36,
      ),
      displaySmall: GoogleFonts.shantellSans(
        fontWeight: FontWeight.w700,
        fontSize: 32,
     ),
      bodyLarge: GoogleFonts.shantellSans(
        fontWeight: FontWeight.w400,
        fontSize: 18,
      ),
      bodyMedium: GoogleFonts.shantellSans(
        fontWeight: FontWeight.w400,
        fontSize: 16,
      ),
      bodySmall: GoogleFonts.shantellSans(
        fontWeight: FontWeight.w400,
        fontSize: 14,
      ),
      labelLarge: GoogleFonts.shantellSans(
        fontWeight: FontWeight.w500,
        fontSize: 16,
    ),
      labelMedium: GoogleFonts.shantellSans(
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      labelSmall: GoogleFonts.shantellSans(
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
      titleLarge: GoogleFonts.shantellSans(
        fontWeight: FontWeight.w400,
        fontSize: 12,
      ),
      titleMedium: GoogleFonts.shantellSans(
        fontWeight: FontWeight.w400,
        fontSize: 11,
      ),
    )
  );
}
